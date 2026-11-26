import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

/// What a probe learns about a file (task 7.3).
@immutable
class ProbedDetails {
  const new({
    this.duration,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.title,
    this.artist,
    this.album,
    this.trackNo,
    this.hasCover = false,
  });

  final Duration? duration;
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? audioCodec;
  final String? title;
  final String? artist;
  final String? album;
  final int? trackNo;

  /// Music with a picture attached (album art).
  final bool hasCover;
}

/// Reads a file's details and makes its library thumbnail.
abstract interface class MediaProber {
  /// Null when the scan already knew the details, or the file can't be
  /// read.
  Future<ProbedDetails?> probe(String uri);

  /// A picture for the library: a frame of a video, a song's cover. Null
  /// when there is none.
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  });
}

/// Desktop: a hidden mpv opens the file paused and reads what the
/// container says (no decoding); thumbnails come from the preview
/// thumbnailer.
class MpvMediaProber implements MediaProber {
  new({required this.previews, PlayerBackend Function()? backendFactory})
    : _factory = backendFactory ?? (() => MediaKitBackend(withVideo: false));

  final PreviewSource previews;
  final PlayerBackend Function() _factory;
  PlayerBackend? _backend;

  @override
  Future<ProbedDetails?> probe(String uri) async {
    final b = _backend ??= await _setUp();
    try {
      await b.command(['loadfile', uri, 'replace']);
      final end = DateTime.now().add(const Duration(seconds: 6));
      String? duration;
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        duration = await b.getProperty('duration');
        if (duration != null && duration.isNotEmpty) break;
      }
      if (duration == null || duration.isEmpty) return null;
      Future<String?> text(String name) async {
        final v = await b.getProperty(name);
        return v == null || v.isEmpty ? null : v;
      }

      int? number(String? v) =>
          v == null ? null : int.tryParse(v.split('/').first);

      // The track list rather than the selected tracks: the player may
      // have video or cover art turned off.
      final count = number(await text('track-list/count')) ?? 0;
      String? videoCodec;
      String? audioCodec;
      int? width;
      int? height;
      var hasCover = false;
      for (var i = 0; i < count; i++) {
        final type = await text('track-list/$i/type');
        if (type == 'video') {
          if (await text('track-list/$i/albumart') == 'yes') {
            hasCover = true;
          } else if (videoCodec == null) {
            videoCodec = await text('track-list/$i/codec');
            width = number(await text('track-list/$i/demux-w'));
            height = number(await text('track-list/$i/demux-h'));
          }
        } else if (type == 'audio') {
          audioCodec ??= await text('track-list/$i/codec');
        }
      }
      final details = ProbedDetails(
        duration: Duration(
          milliseconds: ((double.tryParse(duration) ?? 0) * 1000).round(),
        ),
        width: width,
        height: height,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        title: await text('metadata/by-key/title'),
        artist: await text('metadata/by-key/artist'),
        album: await text('metadata/by-key/album'),
        trackNo: number(await text('metadata/by-key/track')),
        hasCover: hasCover,
      );
      await b.command(['stop']);
      return details;
    } on Object {
      return null;
    }
  }

  Future<PlayerBackend> _setUp() async {
    final b = _factory();
    for (final (k, v) in const [
      ('ao', 'null'),
      ('vo', 'null'),
      ('aid', 'auto'),
      ('vid', 'auto'),
      ('sid', 'no'),
      ('pause', 'yes'),
      ('keep-open', 'yes'),
    ]) {
      await b.setProperty(k, v);
    }
    return b;
  }

  @override
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  }) async {
    if (kind == MediaKind.audio) {
      // The cover is mpv's "video" for a song; none means no picture.
      if (!hasCover) return null;
      return await previews.frameAt(
        uri,
        Duration.zero,
        duration ?? Duration.zero,
      );
    }
    final length = duration ?? Duration.zero;
    return await previews.frameAt(uri, length * 0.1, length, exact: true);
  }

  Future<void> dispose() async => await _backend?.dispose();
}

/// Android: MediaStore already gave the details; thumbnails are the
/// system's (`thumbnail` on `kyndrel/android_media`).
class AndroidMediaProber implements MediaProber {
  new({required this.cacheDir, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kyndrel/android_media');

  final Directory cacheDir;
  final MethodChannel _channel;

  @override
  Future<ProbedDetails?> probe(String uri) async => null;

  @override
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  }) async {
    // The key changes when the file does, so a replaced file gets a new
    // thumbnail (task 8.0).
    final path = p.join(cacheDir.path, 'library', '${mediaCacheKey(uri)}.jpg');
    if (File(path).existsSync()) return path;
    try {
      final ok = await _channel.invokeMethod<bool>('thumbnail', {
        'uri': uri,
        'path': path,
        'size': 320,
      });
      return (ok ?? false) ? path : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
