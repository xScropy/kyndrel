import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';

/// The single entry point to the playback engine (PLAN.md §2).
///
/// Turns the backend's raw streams into [PlaybackState] and [TrackState] and
/// exposes the commands the UI needs. Every mpv property it touches is listed
/// in `docs/mpv-properties.md`. UI code reads it through the Riverpod
/// providers in `player_providers.dart`.
class PlayerService {
  new(this.backend) {
    _subscriptions.addAll([
      backend.playing.listen(
        (v) => _update(
          _state.copyWith(isPlaying: v, isLoaded: v || _state.isLoaded),
        ),
      ),
      backend.completed.listen(_onCompleted),
      backend.buffering.listen((v) => _update(_state.copyWith(isBuffering: v))),
      backend.position.listen((v) => _update(_state.copyWith(position: v))),
      backend.duration.listen(
        (v) => _update(
          _state.copyWith(
            duration: v,
            isLoaded: v > Duration.zero || _state.isLoaded,
          ),
        ),
      ),
      backend.buffer.listen((v) => _update(_state.copyWith(buffered: v))),
      backend.width.listen(
        (v) => _update(
          _state.copyWith(
            videoWidth: v,
            isLoaded: v != null || _state.isLoaded,
          ),
        ),
      ),
      backend.height.listen((v) => _update(_state.copyWith(videoHeight: v))),
      backend.volume.listen((v) => _update(_state.copyWith(volume: v))),
      backend.rate.listen((v) => _update(_state.copyWith(rate: v))),
      backend.error.listen(_onError),
      backend.log.listen(_onLog),
      backend.tracksChanged.listen((_) => unawaited(refreshTracks())),
      backend
          .observe('mute')
          .listen((v) => _update(_state.copyWith(isMuted: v == 'yes'))),
      backend
          .observe('aid')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(audioId: () => _id(v))),
          ),
      backend
          .observe('sid')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(subtitleId: () => _id(v))),
          ),
      backend
          .observe('secondary-sid')
          .listen(
            (v) => _updateTracks(
              _tracks.copyWith(secondarySubtitleId: () => _id(v)),
            ),
          ),
      backend
          .observe('sub-delay')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(subtitleDelay: _seconds(v))),
          ),
      backend
          .observe('audio-delay')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(audioDelay: _seconds(v))),
          ),
    ]);
    unawaited(_configureEngine());
  }

  /// Maximum volume in percent (task 1.6).
  static const double maxVolume = 400;

  /// Label of the limiter filter added above 100 % volume.
  static const limiterLabel = '@kyndrel-limiter';

  /// Lines of mpv log kept for error messages.
  static const logCapacity = 200;

  /// Exposed only so `PlayerVideoView` can reach the video surface.
  final PlayerBackend backend;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _controller = StreamController<PlaybackState>.broadcast();
  final _trackController = StreamController<TrackState>.broadcast();
  final _completions = StreamController<String>.broadcast();
  final _log = ListQueue<PlayerLogLine>();
  PlaybackState _state = PlaybackState.initial;
  TrackState _tracks = TrackState.empty;
  bool _disposed = false;
  bool _limiterEnabled = true;
  bool _limiterActive = false;

  /// Current snapshot.
  PlaybackState get state => _state;
  TrackState get tracks => _tracks;

  /// Every state change, starting with the current state.
  ///
  /// Subscribes to live changes as soon as it is listened to, so nothing
  /// emitted between the replay and the subscription is lost.
  Stream<PlaybackState> get states => _replay(_controller, () => _state);

  /// Track list and selection changes, starting with the current value.
  Stream<TrackState> get trackStates =>
      _replay(_trackController, () => _tracks);

  /// Emits the source each time a file plays to its end. Used by the sleep
  /// timer's "end of episode" modes.
  Stream<String> get completions => _completions.stream;

  Stream<Duration> get position => states.map((s) => s.position).distinct();
  Stream<Duration> get duration => states.map((s) => s.duration).distinct();
  Stream<bool> get buffering => states.map((s) => s.isBuffering).distinct();
  Stream<PlaybackStatus> get status => states.map((s) => s.status).distinct();

  /// Most recent mpv log lines, oldest first.
  List<PlayerLogLine> get recentLog => List.unmodifiable(_log);

  /// The last few warnings/errors, for the "can't play" message.
  String logExcerpt({int lines = 8}) {
    final relevant = _log
        .where((l) => const {'fatal', 'error', 'warn'}.contains(l.level))
        .toList();
    return relevant
        .skip(math.max(0, relevant.length - lines))
        .map((l) => '[${l.prefix}] ${l.text}')
        .join('\n');
  }

  // ---------------------------------------------------------------- opening

  /// Opens a local path or URL. Starts playing unless [play] is false.
  Future<void> open(String source, {bool play = true}) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(source, 'source', 'must not be empty');
    }
    _log.clear();
    _update(
      PlaybackState(
        source: trimmed,
        volume: _state.volume,
        isMuted: _state.isMuted,
        rate: _state.rate,
      ),
    );
    _updateTracks(TrackState.empty);
    await backend.open(trimmed, play: play);
  }

  /// Stops playback and returns to idle.
  Future<void> close() async {
    await backend.stop();
    _update(
      PlaybackState(
        volume: _state.volume,
        isMuted: _state.isMuted,
        rate: _state.rate,
      ),
    );
    _updateTracks(TrackState.empty);
  }

  // -------------------------------------------------------------- transport

  Future<void> play() async {
    if (_state.source == null) return;
    // Pressing play at the end restarts from the beginning, like most players.
    if (_state.isCompleted) await backend.seek(Duration.zero);
    await backend.play();
  }

  Future<void> pause() => backend.pause();

  Future<void> playOrPause() => _state.isPlaying ? pause() : play();

  /// Seeks to [position], clamped to the file's length when it is known.
  Future<void> seek(Duration position) async {
    if (_state.source == null) return;
    await backend.seek(_clamp(position));
  }

  /// Seeks relative to the current position (negative goes back).
  Future<void> seekBy(Duration offset) => seek(_state.position + offset);

  // ------------------------------------------------------------------ audio

  /// Sets the volume, 0–[maxVolume] percent. Unmutes when raised above 0.
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0, maxVolume).toDouble();
    _update(_state.copyWith(volume: v));
    await backend.setVolume(v);
    if (v > 0 && _state.isMuted) await setMuted(muted: false);
    await _syncLimiter();
  }

  Future<void> changeVolumeBy(double delta) => setVolume(_state.volume + delta);

  Future<void> setMuted({required bool muted}) async {
    _update(_state.copyWith(isMuted: muted));
    await backend.setProperty('mute', muted ? 'yes' : 'no');
  }

  Future<void> toggleMute() => setMuted(muted: !_state.isMuted);

  /// Whether to add a limiter above 100 % to reduce clipping.
  Future<void> setLimiterEnabled({required bool enabled}) async {
    _limiterEnabled = enabled;
    await _syncLimiter();
  }

  Future<void> selectAudioTrack(int id) => backend.setProperty('aid', '$id');

  Future<void> setAudioDelay(Duration delay) =>
      backend.setProperty('audio-delay', _formatSeconds(delay));

  // ------------------------------------------------------------------ speed

  static const double minRate = 0.1;
  static const double maxRate = 4;

  Future<void> setRate(double rate) async {
    final r = rate.clamp(minRate, maxRate);
    _update(_state.copyWith(rate: r));
    await backend.setRate(r);
  }

  // -------------------------------------------------------------- subtitles

  /// Selects a subtitle track, or turns subtitles off when [id] is null.
  Future<void> selectSubtitle(int? id) =>
      backend.setProperty('sid', id == null ? 'no' : '$id');

  /// Second subtitle line shown at the top (dual subtitles).
  Future<void> selectSecondarySubtitle(int? id) =>
      backend.setProperty('secondary-sid', id == null ? 'no' : '$id');

  /// Adds an external subtitle file or URL and, by default, selects it.
  Future<void> addSubtitle(String path, {bool select = true, String? title}) =>
      backend.command([
        'sub-add',
        path,
        if (select) 'select' else 'auto',
        ?title,
      ]);

  Future<void> setSubtitleDelay(Duration delay) =>
      backend.setProperty('sub-delay', _formatSeconds(delay));

  Future<void> applySubtitleStyle(SubtitleStyle style) async {
    for (final e in style.toMpvOptions().entries) {
      await backend.setProperty(e.key, e.value);
    }
  }

  /// Load subtitle files named like the video from the same folder
  /// (mpv `sub-auto=fuzzy`), or turn that off.
  Future<void> setAutoLoadSubtitles({required bool enabled}) =>
      backend.setProperty('sub-auto', enabled ? 'fuzzy' : 'no');

  // ------------------------------------------------------------------ video

  /// Forces a display aspect ratio such as `16:9`, or the file's own when
  /// null.
  Future<void> setAspectOverride(String? ratio) =>
      backend.setProperty('video-aspect-override', ratio ?? 'no');

  /// Rotates the picture clockwise by 0, 90, 180 or 270 degrees.
  Future<void> setRotation(int degrees) =>
      backend.setProperty('video-rotate', '${degrees % 360}');

  // ------------------------------------------------------------------- info

  /// The hardware decoder mpv is using (e.g. `d3d11va`), or null if decoding
  /// in software or unknown.
  Future<String?> hardwareDecoder() async {
    final value = await backend.getProperty('hwdec-current');
    if (value == null || value.isEmpty || value == 'no') return null;
    return value;
  }

  /// mpv properties shown in the diagnostics overlay (`--diagnostics`).
  static const diagnosticProperties = [
    'hwdec-current',
    'video-codec',
    'width',
    'height',
    'container-fps',
    'estimated-vf-fps',
    'frame-drop-count',
  ];

  /// Current values of [diagnosticProperties]; unavailable ones are omitted.
  Future<Map<String, String>> diagnostics() =>
      _readProperties(diagnosticProperties);

  /// mpv properties shown in the media info dialog.
  static const mediaInfoProperties = [
    'filename',
    'path',
    'file-format',
    'file-size',
    'duration',
    'video-codec',
    'video-params/w',
    'video-params/h',
    'container-fps',
    'video-params/pixelformat',
    'video-params/colormatrix',
    'video-params/primaries',
    'video-params/gamma',
    'video-bitrate',
    'audio-codec',
    'audio-params/channel-count',
    'audio-params/samplerate',
    'audio-bitrate',
    'hwdec-current',
  ];

  Future<Map<String, String>> mediaInfo() =>
      _readProperties(mediaInfoProperties);

  /// Re-reads mpv's `track-list`.
  Future<void> refreshTracks() async {
    final count = int.tryParse(
      await backend.getProperty('track-list/count') ?? '',
    );
    if (count == null) return;
    final video = <MediaTrack>[];
    final audio = <MediaTrack>[];
    final subs = <MediaTrack>[];
    for (var i = 0; i < count; i++) {
      Future<String?> p(String name) =>
          backend.getProperty('track-list/$i/$name');
      final id = int.tryParse(await p('id') ?? '');
      final type = switch (await p('type')) {
        'video' => MediaTrackType.video,
        'audio' => MediaTrackType.audio,
        'sub' => MediaTrackType.subtitle,
        _ => null,
      };
      if (id == null || type == null) continue;
      final track = MediaTrack(
        id: id,
        type: type,
        title: _nonEmpty(await p('title')),
        language: _nonEmpty(await p('lang')),
        codec: _nonEmpty(await p('codec')),
        isExternal: await p('external') == 'yes',
        externalFilename: _nonEmpty(await p('external-filename')),
        isDefault: await p('default') == 'yes',
        isForced: await p('forced') == 'yes',
        channels: int.tryParse(await p('demux-channel-count') ?? ''),
      );
      (switch (type) {
        MediaTrackType.video => video,
        MediaTrackType.audio => audio,
        MediaTrackType.subtitle => subs,
      }).add(track);
    }
    _updateTracks(
      _tracks.copyWith(video: video, audio: audio, subtitles: subs),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _controller.close();
    await _trackController.close();
    await _completions.close();
    await backend.dispose();
  }

  // ---------------------------------------------------------------- private

  Future<void> _configureEngine() async {
    await backend.setProperty('volume-max', maxVolume.toStringAsFixed(0));
    await backend.setProperty('audio-pitch-correction', 'yes');
  }

  Future<void> _syncLimiter() async {
    final want = _limiterEnabled && _state.volume > 100;
    if (want == _limiterActive) return;
    _limiterActive = want;
    await backend.command(
      want
          ? ['af', 'add', '$limiterLabel:lavfi=[alimiter=limit=0.9]']
          : ['af', 'remove', limiterLabel],
    );
  }

  Future<Map<String, String>> _readProperties(List<String> names) async {
    final values = <String, String>{};
    for (final name in names) {
      final v = await backend.getProperty(name);
      if (v != null && v.isNotEmpty) values[name] = v;
    }
    return values;
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final d = _state.duration;
    if (d > Duration.zero && position > d) return d;
    return position;
  }

  void _onCompleted(bool completed) {
    final wasCompleted = _state.isCompleted;
    _update(_state.copyWith(isCompleted: completed));
    final source = _state.source;
    if (completed && !wasCompleted && source != null && !_disposed) {
      _completions.add(source);
    }
  }

  void _onError(String message) {
    if (message.trim().isEmpty) return;
    _update(_state.copyWith(errorMessage: message));
  }

  void _onLog(PlayerLogLine line) {
    _log.addLast(line);
    while (_log.length > logCapacity) {
      _log.removeFirst();
    }
  }

  void _update(PlaybackState next) {
    if (_disposed || next == _state) return;
    _state = next;
    _controller.add(next);
  }

  void _updateTracks(TrackState next) {
    if (_disposed || next == _tracks) return;
    _tracks = next;
    _trackController.add(next);
  }

  static Stream<T> _replay<T>(StreamController<T> source, T Function() now) =>
      Stream.multi((listener) {
        listener.add(now());
        final sub = source.stream.listen(
          listener.addSync,
          onDone: listener.closeSync,
        );
        listener.onCancel = sub.cancel;
      });

  static int? _id(String value) => int.tryParse(value);

  static Duration _seconds(String value) {
    final s = double.tryParse(value) ?? 0;
    return Duration(microseconds: (s * 1e6).round());
  }

  static String _formatSeconds(Duration d) =>
      (d.inMicroseconds / 1e6).toStringAsFixed(3);

  static String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
}
