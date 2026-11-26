import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/player/storyboard_writer.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

/// Preview frames on Android (task 6.4): `MediaMetadataRetriever` through
/// `kyndrel/frames` (MainActivity.kt). It reads `content://` files, uses
/// the hardware decoder and needs no second mpv. Same cache layout as
/// [PreviewThumbnailer]: `<cache>/previews/<key>/<second>.jpg`.
class AndroidFrameSource implements PreviewSource {
  new({required this.cacheDir, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kyndrel/frames');

  /// Bigger than the desktop's: the phone preview is ~40 % of the screen.
  static const width = 480;

  final Directory cacheDir;
  final MethodChannel _channel;
  final _queue =
      Queue<({String source, int second, String path, bool exact})>();
  final _waiting = <String, Completer<String?>>{};
  bool _busy = false;

  @override
  Duration stepFor(Duration duration) {
    final s = (duration.inSeconds / 200).ceil();
    return Duration(seconds: s < 2 ? 2 : s);
  }

  String _path(String source, int second, {bool exact = false}) => p.join(
    cacheDir.path,
    'previews',
    mediaCacheKey(source),
    exact ? '${second}x.jpg' : '$second.jpg',
  );

  @override
  Future<String?> frameAt(
    String source,
    Duration at,
    Duration duration, {
    bool exact = false,
    bool background = false,
  }) {
    // Network streams: decoding a second copy costs data and time.
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Future.value();
    }
    final step = stepFor(duration).inSeconds;
    final second = exact ? at.inSeconds : (at.inSeconds ~/ step) * step;
    final path = _path(source, second, exact: exact);
    final pending = _waiting[path];
    if (pending != null) return pending.future;
    if (File(path).existsSync()) return Future.value(path);
    final completer = _waiting[path] = Completer<String?>();
    // Only the newest few positions matter while the finger moves.
    while (_queue.length >= 3) {
      final dropped = _queue.removeFirst();
      _waiting.remove(dropped.path)?.complete();
    }
    _queue.add((source: source, second: second, path: path, exact: exact));
    unawaited(_pump());
    return completer.future;
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final r = _queue.removeLast();
        String? result;
        try {
          final ok = await _channel.invokeMethod<bool>('frame', {
            'source': r.source,
            'ms': r.second * 1000,
            'width': width,
            'path': r.path,
            // The exact frame decodes from the keyframe on: slower.
            'exact': r.exact,
          });
          if ((ok ?? false) && File(r.path).existsSync()) result = r.path;
        } on PlatformException {
          result = null;
        } on MissingPluginException {
          result = null;
        }
        _waiting.remove(r.path)?.complete(result);
      }
    } finally {
      _busy = false;
    }
  }
}

/// Storyboards on Android (tasks 7.2, 8.2): MediaMetadataRetriever walks
/// the video on its own thread (`storyboard` on `kyndrel/frames`), level by
/// level, nearest keyframe for each step, writing `<i>.jpg` tiles. Dart then
/// packs them into sheets in a background isolate.
///
/// The native loop reports nothing while it runs, so the tiles folder is
/// listed (asynchronously) once a second to show frames as they appear.
class AndroidStoryboardSource implements StoryboardSource {
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kyndrel/frames');

  final MethodChannel _channel;

  /// How often the tiles folder is checked during a level.
  static const progressInterval = Duration(seconds: 1);

  @override
  void focus(Duration at) {
    // The native loop goes in order; the coarse level covers the video.
  }

  @override
  Future<bool> render(
    Storyboard board, {
    void Function(Storyboard board)? onChange,
  }) async {
    // Packing waits for each level's end: the native loop skips frames
    // whose tiles exist, so they must stay until then.
    final writer = StoryboardWriter(
      board,
      onChange: onChange,
      packEarly: false,
    );
    for (final level in board.levels) {
      if (level.complete) continue;
      final n = level.spec.index;
      final dir = board.tilesDirectory(n);
      await Directory(dir).create(recursive: true);
      final progress = Timer.periodic(
        progressInterval,
        (_) => unawaited(_report(writer, n, dir)),
      );
      bool? ok;
      try {
        ok = await _channel.invokeMethod<bool>('storyboard', {
          'source': board.source,
          'dir': dir,
          'stepMs': level.spec.step.inMilliseconds,
          'count': level.spec.count,
          'width': level.spec.width,
        });
      } on PlatformException {
        ok = false;
      } on MissingPluginException {
        ok = false;
      } finally {
        progress.cancel();
      }
      if (!(ok ?? false)) return false;
      await _report(writer, n, dir);
      if (writer.board.levels[n].tiles.isEmpty &&
          writer.board.levels[n].sheets.isEmpty) {
        return false; // Nothing could be decoded.
      }
      await writer.finishLevel(n);
    }
    return writer.board.complete;
  }

  /// Tells [writer] about tiles the native loop wrote.
  static Future<void> _report(
    StoryboardWriter writer,
    int level,
    String dir,
  ) async {
    final count = writer.board.levels[level].spec.count;
    try {
      await for (final f in Directory(dir).list()) {
        if (!f.path.endsWith('.jpg')) continue;
        final i = int.tryParse(p.basenameWithoutExtension(f.path));
        if (i != null && i < count) writer.tileWritten(level, i);
      }
    } on FileSystemException {
      // Gone: the render was cancelled.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancelStoryboard');
    } on PlatformException {
      // Nothing running.
    } on MissingPluginException {
      // Tests.
    }
  }
}
