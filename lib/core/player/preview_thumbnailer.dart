import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

/// Seek-bar preview frames (task 3.7).
abstract interface class PreviewSource {
  /// Seconds between cached frames for a file of [duration].
  Duration stepFor(Duration duration);

  /// A JPEG of [source] near [at], from the cache or rendered now. Null if
  /// it can't be made (stream, no video, error). [exact]: the frame at
  /// [at]'s second rather than the nearest cached step (task 7.2, when the
  /// finger rests on the seek bar). [background]: for the library, after
  /// anything the user is looking at, and never dropped (task 8.1).
  Future<String?> frameAt(
    String source,
    Duration at,
    Duration duration, {
    bool exact = false,
    bool background = false,
  });
}

/// Renders frames with the shared [FrameEngine] (task 8.1). The file stays
/// open between requests, so the next frame is a seek, not a reload.
/// Frames are cached under `<cache>/previews/<mediaCacheKey>/<second>.jpg`.
class PreviewThumbnailer implements PreviewSource {
  /// [engine] is shared in the app; tests may pass [backendFactory] for an
  /// engine of their own.
  new({
    required this.cacheDir,
    FrameEngine? engine,
    PlayerBackend Function()? backendFactory,
  }) : _engine = engine ?? FrameEngine(backendFactory: backendFactory),
       _ownsEngine = engine == null;

  /// Preview width in pixels.
  static const width = 240;

  /// How long one frame may take.
  static const frameTimeout = Duration(seconds: 10);

  /// Options of the preview profile.
  static const options = [
    ('vo', 'image'),
    ('vid', 'auto'),
    ('aid', 'no'),
    // A song's cover art is its picture (task 7.3).
    ('audio-display', 'embedded-first'),
    ('vo-image-jpeg-quality', '75'),
    ('vf', 'scale=w=$width:h=-2'),
    ('hr-seek', 'yes'),
  ];

  final Directory cacheDir;
  final FrameEngine _engine;
  final bool _ownsEngine;

  /// One render at a time; newer requests replace queued ones.
  final _queue = Queue<_Request>();
  bool _busy = false;
  final _inFlight = <String, Future<String?>>{};

  @override
  Duration stepFor(Duration duration) {
    // About 200 frames per file, at least 2 s apart.
    final s = (duration.inSeconds / 200).ceil();
    return Duration(seconds: s < 2 ? 2 : s);
  }

  String _cachePath(String source, int second, {bool exact = false}) => p.join(
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
    // Only local files: rendering a network stream twice is too costly.
    if (source.contains('://') && !source.startsWith('file://')) {
      return Future.value();
    }
    final step = stepFor(duration).inSeconds;
    final second = exact ? at.inSeconds : (at.inSeconds ~/ step) * step;
    final path = _cachePath(source, second, exact: exact);
    if (File(path).existsSync()) return Future.value(path);
    return _inFlight.putIfAbsent(
      path,
      () => background
          ? _background(_Request(source, second, path))
          : _frame(source, second, path),
    );
  }

  Future<String?> _frame(String source, int second, String path) async {
    // Never finishes synchronously (it awaits the render), so the entry is
    // stored before `finally` removes it.
    try {
      final request = _Request(source, second, path);
      // Drop stale hover positions: only the latest few matter.
      while (_queue.length >= 3) {
        _queue.removeFirst().completer.complete();
      }
      _queue.add(request);
      unawaited(_pump());
      return await request.completer.future;
    } finally {
      _inFlight.remove(path)?.ignore();
    }
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final r = _queue.removeLast();
        r.completer.complete(await _render(r));
      }
    } finally {
      _busy = false;
    }
  }

  /// Library pictures skip the hover queue (which drops old requests).
  Future<String?> _background(_Request r) async {
    try {
      return await _render(r, FrameJob.probe);
    } finally {
      _inFlight.remove(r.path)?.ignore();
    }
  }

  Future<String?> _render(_Request r, [FrameJob kind = FrameJob.exact]) async {
    try {
      return await _engine.run(kind, (s) async {
        final b = s.backend;
        final tag = 'preview|${r.source}';
        await s.clearScratch();
        var reload = s.loaded != tag;
        if (!reload) {
          // Seeking to where it already is draws nothing new: reload then.
          final pos = double.tryParse(await b.getProperty('time-pos') ?? '');
          reload = pos == null || (pos - r.second).abs() < 0.05;
        }
        if (reload) {
          await s.configure('preview', options);
          await b.setProperty('start', '${r.second}');
          await b.command(['loadfile', r.source, 'replace']);
          s.loaded = tag;
        } else {
          await b.command(['seek', '${r.second}', 'absolute+exact']);
        }
        final next = await s.nextPicture(timeout: frameTimeout);
        final picture = next.file;
        if (picture == null) {
          s.loaded = null;
          return null;
        }
        await File(r.path).parent.create(recursive: true);
        await picture.rename(r.path);
        return r.path;
      });
    } on Object {
      return null;
    }
  }

  Future<void> dispose() async {
    for (final r in _queue) {
      r.completer.complete();
    }
    _queue.clear();
    if (_ownsEngine) await _engine.dispose();
  }
}

class _Request {
  new(this.source, this.second, this.path);
  final String source;
  final int second;
  final String path;
  final completer = Completer<String?>();
}

final previewSourceProvider = Provider<PreviewSource>((ref) {
  final t = PreviewThumbnailer(
    cacheDir: ref.watch(appCacheDirProvider),
    engine: ref.watch(frameEngineProvider),
  );
  ref.onDispose(t.dispose);
  return t;
});
