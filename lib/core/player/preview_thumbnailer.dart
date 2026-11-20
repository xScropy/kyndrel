import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:path/path.dart' as p;

/// Seek-bar preview frames (task 3.7).
abstract interface class PreviewSource {
  /// Seconds between cached frames for a file of [duration].
  Duration stepFor(Duration duration);

  /// A JPEG of [source] near [at], from the cache or rendered now. Null if
  /// it can't be made (stream, no video, error). [exact]: the frame at
  /// [at]'s second rather than the nearest cached step (task 7.2, when the
  /// finger rests on the seek bar).
  Future<String?> frameAt(
    String source,
    Duration at,
    Duration duration, {
    bool exact = false,
  });
}

/// Renders frames with a second, hidden mpv: `vo=image` writes one JPEG per
/// request (`frames=1`) into a scratch folder; frames are cached under
/// `<cache>/previews/<hash of source>/<second>.jpg`.
class PreviewThumbnailer implements PreviewSource {
  new({required this.cacheDir, PlayerBackend Function()? backendFactory})
    : _factory = backendFactory ?? (() => MediaKitBackend(withVideo: false));

  /// Preview width in pixels.
  static const width = 240;

  final Directory cacheDir;
  final PlayerBackend Function() _factory;
  PlayerBackend? _backend;

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
    fnv1a64(source),
    exact ? '${second}x.jpg' : '$second.jpg',
  );

  @override
  Future<String?> frameAt(
    String source,
    Duration at,
    Duration duration, {
    bool exact = false,
  }) {
    // Only local files: rendering a network stream twice is too costly.
    if (source.contains('://') && !source.startsWith('file://')) {
      return Future.value();
    }
    final step = stepFor(duration).inSeconds;
    final second = exact ? at.inSeconds : (at.inSeconds ~/ step) * step;
    final path = _cachePath(source, second, exact: exact);
    if (File(path).existsSync()) return Future.value(path);
    return _inFlight.putIfAbsent(path, () {
      final request = _Request(source, second, path);
      // Drop stale hover positions: only the latest few matter.
      while (_queue.length >= 3) {
        _queue.removeFirst().completer.complete();
      }
      _queue.add(request);
      unawaited(_pump());
      // A block body: returning remove()'s value (this same future) would
      // make whenComplete wait on itself.
      return request.completer.future.whenComplete(() {
        _inFlight.remove(path)?.ignore();
      });
    });
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

  Future<String?> _render(_Request r) async {
    final scratch = Directory(p.join(cacheDir.path, 'previews', 'scratch'));
    try {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      scratch.createSync(recursive: true);
      final b = _backend ??= await _setUp();
      await b.setProperty('vo-image-outdir', scratch.path);
      await b.setProperty('start', '${r.second}');
      await b.command(['loadfile', r.source, 'replace']);
      // mpv writes the single frame and stops; wait for the file.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      var frames = <File>[];
      while (frames.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        frames = scratch
            .listSync()
            .whereType<File>()
            .where((f) => f.lengthSync() > 0)
            .toList();
      }
      if (frames.isEmpty) return null;
      // Let mpv finish writing.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final out = File(r.path)..parent.createSync(recursive: true);
      frames.first.renameSync(out.path);
      return out.path;
    } on Object {
      return null;
    }
  }

  Future<PlayerBackend> _setUp() async {
    final b = _factory();
    for (final (k, v) in const [
      ('ao', 'null'),
      ('aid', 'no'),
      ('sid', 'no'),
      ('vid', 'auto'),
      ('vo', 'image'),
      ('vo-image-format', 'jpg'),
      ('vo-image-jpeg-quality', '75'),
      ('vf', 'scale=w=$width:h=-2'),
      ('frames', '1'),
      ('hr-seek', 'yes'),
      ('keep-open', 'no'),
    ]) {
      await b.setProperty(k, v);
    }
    return b;
  }

  Future<void> dispose() async {
    for (final r in _queue) {
      r.completer.complete();
    }
    _queue.clear();
    await _backend?.dispose();
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
  final t = PreviewThumbnailer(cacheDir: ref.watch(appCacheDirProvider));
  ref.onDispose(t.dispose);
  return t;
});
