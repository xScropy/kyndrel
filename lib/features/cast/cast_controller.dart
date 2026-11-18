import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/multicast_lock.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/remote_target.dart';
import 'package:kyndrel/core/subtitles/subtitle_file.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/features/cast/cast_device.dart';
import 'package:kyndrel/features/cast/cast_server.dart';
import 'package:kyndrel/features/cast/cast_session.dart';
import 'package:kyndrel/features/cast/castv2.dart';
import 'package:kyndrel/features/cast/chromecast_discovery.dart';
import 'package:kyndrel/features/cast/dlna.dart';
import 'package:path/path.dart' as p;

@immutable
class CastState {
  const new({
    this.devices = const [],
    this.scanning = false,
    this.connecting,
    this.active,
    this.transcoding = false,
    this.error,
  });

  final List<CastDevice> devices;
  final bool scanning;
  final CastDevice? connecting;
  final CastDevice? active;
  final bool transcoding;
  final String? error;

  CastState copyWith({
    List<CastDevice>? devices,
    bool? scanning,
    CastDevice? Function()? connecting,
    CastDevice? Function()? active,
    bool? transcoding,
    String? Function()? error,
  }) => CastState(
    devices: devices ?? this.devices,
    scanning: scanning ?? this.scanning,
    connecting: connecting != null ? connecting() : this.connecting,
    active: active != null ? active() : this.active,
    transcoding: transcoding ?? this.transcoding,
    error: error != null ? error() : this.error,
  );
}

/// Discovery, connection and the local media server, swappable in tests.
abstract interface class CastPlatform {
  Future<List<CastDevice>> discover();
  Future<CastSession> connect(CastDevice device);
  Future<CastServer> startServer();

  /// Whether FFmpeg is available for transcoding.
  Future<bool> canTranscode();
}

class DefaultCastPlatform implements CastPlatform {
  const new();

  @override
  Future<List<CastDevice>> discover() async {
    final r = await MulticastLock.hold(
      () => Future.wait([discoverChromecasts(), discoverDlna()]),
    );
    return [...r[0], ...r[1]];
  }

  @override
  Future<CastSession> connect(CastDevice d) async => switch (d.kind) {
    CastKind.chromecast => await ChromecastSession.connect(
      d.name,
      d.host,
      d.port,
    ),
    CastKind.dlna => DlnaSession(d),
  };

  @override
  Future<CastServer> startServer() => CastServer.start();

  @override
  Future<bool> canTranscode() async {
    try {
      return (await Process.run('ffmpeg', ['-version'])).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

final castPlatformProvider = Provider<CastPlatform>(
  (ref) => const DefaultCastPlatform(),
);

/// Casting to Chromecast and DLNA devices (task 4.4, beta). The file is
/// served from this machine; unsupported codecs are transcoded live with
/// FFmpeg for Chromecasts. Play, pause, seek and volume go to the device
/// through `PlayerService`.
class CastController extends Notifier<CastState> {
  CastServer? _server;

  @override
  CastState build() {
    ref.onDispose(() => unawaited(_server?.close()));
    return const CastState();
  }

  CastPlatform get _platform => ref.read(castPlatformProvider);

  Future<void> scan() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, error: () => null);
    try {
      final found = await _platform.discover();
      state = state.copyWith(devices: found, scanning: false);
    } on Object catch (e) {
      state = state.copyWith(scanning: false, error: () => 'Search failed: $e');
    }
  }

  Future<void> castTo(CastDevice device) async {
    final service = ref.read(playerServiceProvider);
    final source = service.state.source;
    if (source == null) return;
    state = state.copyWith(connecting: () => device, error: () => null);
    try {
      final session = await _platform.connect(device);
      final media = await _prepare(source, device, service.state.position);
      await session.loadMedia(media.media);
      final target = media.transcoded
          ? _TranscodedTarget(session, media.media, _server!)
          : session;
      await service.attachRemote(target);
      state = state.copyWith(
        connecting: () => null,
        active: () => device,
        transcoding: media.transcoded,
      );
    } on Object catch (e) {
      await _server?.close();
      _server = null;
      state = state.copyWith(
        connecting: () => null,
        error: () => "Couldn't cast to ${device.name}: $e",
      );
    }
  }

  Future<({CastMedia media, bool transcoded})> _prepare(
    String source,
    CastDevice device,
    Duration at,
  ) async {
    final title = parseMediaTitle(source).title;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      // The device fetches network videos itself.
      return (
        media: CastMedia(
          url: Uri.parse(source),
          contentType: CastServer.contentTypeOf(Uri.parse(source).path),
          title: title,
          startAt: at,
        ),
        transcoded: false,
      );
    }
    if (source.contains('://')) {
      throw const CastException('Only local files and web videos can be cast.');
    }
    final server = _server ??= await _platform.startServer();
    final tracks = ref.read(playerServiceProvider).tracks;
    String? vtt;
    final sub = tracks.selectedSubtitle;
    final subFile = sub?.externalFilename;
    if (sub != null && sub.isExternal && subFile != null) {
      try {
        vtt = writeVtt(
          parseSubtitles(
            File(subFile).readAsStringSync(),
            extension: p.extension(subFile),
          ),
        );
      } on Object {
        vtt = null;
      }
    }
    final url = server.serve(source, vtt: vtt);
    final playable =
        device.kind == CastKind.dlna ||
        chromecastCanPlay(
          videoCodec: tracks.video.firstOrNull?.codec,
          audioCodec: tracks.audio.firstOrNull?.codec,
          path: source,
        );
    if (!playable && await _platform.canTranscode()) {
      return (
        media: CastMedia(
          url: server.transcodeUrl(at),
          contentType: 'video/mp4',
          title: title,
          subtitleUrl: server.subtitleUrl,
        ),
        transcoded: true,
      );
    }
    return (
      media: CastMedia(
        url: url,
        contentType: CastServer.contentTypeOf(source),
        title: title,
        startAt: at,
        subtitleUrl: server.subtitleUrl,
      ),
      transcoded: false,
    );
  }

  /// Back to this computer, paused where the device was.
  Future<void> stop() async {
    await ref.read(playerServiceProvider).detachRemote();
    await _server?.close();
    _server = null;
    state = state.copyWith(active: () => null, transcoding: false);
  }
}

/// A live transcode can't seek: seeking restarts it at the new time, and
/// positions are offset by that start.
class _TranscodedTarget implements RemoteTarget {
  new(this._session, this._media, this._server);

  final CastSession _session;
  final CastMedia _media;
  final CastServer _server;
  Duration _offset = Duration.zero;

  @override
  String get name => _session.name;

  @override
  Stream<RemoteStatus> get status => _session.status.map(
    (s) => RemoteStatus(
      position: s.position + _offset,
      playing: s.playing,
      finished: s.finished,
    ),
  );

  @override
  Future<void> seek(Duration position) async {
    _offset = position;
    await _session.loadMedia(
      CastMedia(
        url: _server.transcodeUrl(position),
        contentType: _media.contentType,
        title: _media.title,
        subtitleUrl: _media.subtitleUrl,
      ),
    );
  }

  @override
  Future<void> play() => _session.play();

  @override
  Future<void> pause() => _session.pause();

  @override
  Future<void> setVolume(double volume) => _session.setVolume(volume);

  @override
  Future<void> stop() => _session.stop();
}

final castProvider = NotifierProvider<CastController, CastState>(
  CastController.new,
);
