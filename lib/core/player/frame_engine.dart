import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:path/path.dart' as p;

/// What a frame-engine job is for, most urgent first.
enum FrameJob {
  /// A frame the user is looking at now (finger resting on the seek bar).
  exact,

  /// The storyboard of the file playing.
  storyboard,

  /// Library details and thumbnails.
  probe,
}

/// One hidden mpv for all frame work on desktop (task 8.1): storyboards,
/// seek-bar frames and library probing used to have one each.
///
/// - Jobs run one at a time, the most urgent first ([FrameJob]).
/// - Long jobs (a storyboard) check [FrameSession.shouldYield] between
///   frames and hand the engine over when something more urgent waits.
/// - mpv starts on the first job and is closed after [idleTimeout] without
///   work, so an idle Kyndrel has only the player's mpv.
/// - Lean decoding: software, no audio, small demuxer cache, the cheaper
///   decoder shortcuts. Pictures are small, so quality loss doesn't show.
class FrameEngine {
  new({
    PlayerBackend Function()? backendFactory,
    this.scratchDir,
    this.idleTimeout = const Duration(seconds: 30),
  }) : _factory = backendFactory ?? (() => MediaKitBackend(withVideo: false));

  /// Where mpv writes its pictures; a temporary folder when null.
  final Directory? scratchDir;
  final Duration idleTimeout;
  final PlayerBackend Function() _factory;

  /// Options every job shares, set once when mpv starts.
  static const leanOptions = [
    ('ao', 'null'),
    ('sid', 'no'),
    ('hwdec', 'no'),
    ('vd-lavc-threads', '2'),
    ('vd-lavc-skiploopfilter', 'all'),
    ('vd-lavc-fast', 'yes'),
    ('cache', 'no'),
    ('demuxer-max-bytes', '4MiB'),
    ('demuxer-max-back-bytes', '1MiB'),
    ('pause', 'yes'),
    ('keep-open', 'always'),
    ('vo-image-format', 'jpg'),
  ];

  /// mpv instances started so far (tests check there is only one at a time).
  int get started => _started;
  int _started = 0;

  /// Whether mpv is running now.
  bool get isRunning => _session != null;

  FrameSession? _session;
  Future<void>? _closing;
  bool _busy = false;
  final _waiting = <_Waiter>[];
  int _order = 0;
  Timer? _idle;
  bool _disposed = false;

  /// Runs [job] with the engine to itself, after any more urgent job.
  Future<T> run<T>(
    FrameJob kind,
    Future<T> Function(FrameSession s) job,
  ) async {
    if (_disposed) throw const FrameEngineClosed();
    await _acquire(kind);
    try {
      final s = (_session ??= await _start()).._kind = kind;
      return await job(s);
    } finally {
      _release();
    }
  }

  Future<void> _acquire(FrameJob kind) async {
    _idle?.cancel();
    if (!_busy && _waiting.isEmpty) {
      _busy = true;
      return;
    }
    final w = _Waiter(kind, _order++);
    _waiting.add(w);
    await w.ready.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Most urgent first, then in order of arrival.
      _waiting.sort(
        (a, b) => a.kind.index != b.kind.index
            ? a.kind.index.compareTo(b.kind.index)
            : a.order.compareTo(b.order),
      );
      _waiting.removeAt(0).ready.complete();
      return;
    }
    _busy = false;
    _idle?.cancel();
    _idle = Timer(idleTimeout, () => unawaited(_close()));
  }

  /// Whether a job more urgent than [kind] is waiting.
  bool _urgentWaiting(FrameJob kind) =>
      _waiting.any((w) => w.kind.index < kind.index);

  Future<FrameSession> _start() async {
    // Never two hidden mpvs: wait for the last one to close.
    await _closing;
    final dir =
        scratchDir ??
        await Directory.systemTemp.createTemp('kyndrel_frame_engine');
    await dir.create(recursive: true);
    final b = _factory();
    _started++;
    for (final (k, v) in leanOptions) {
      await b.setProperty(k, v);
    }
    await b.setProperty('vo-image-outdir', dir.path);
    return FrameSession._(this, b, dir, ownsScratch: scratchDir == null);
  }

  /// Closes mpv now if nothing is running; the next job starts it again.
  Future<void> releaseIdle() async {
    if (_busy) return;
    await _close();
  }

  Future<void> _close() async {
    _idle?.cancel();
    final s = _session;
    if (s == null || _busy) return;
    _session = null;
    final closing = _closing = () async {
      try {
        await s.backend.dispose();
      } on Object {
        // Already gone.
      }
      if (s._ownsScratch) {
        try {
          await s.scratch.delete(recursive: true);
        } on FileSystemException {
          // Already gone.
        }
      }
    }();
    await closing;
  }

  Future<void> dispose() async {
    _disposed = true;
    _idle?.cancel();
    for (final w in _waiting) {
      w.ready.completeError(const FrameEngineClosed());
    }
    _waiting.clear();
    _busy = false;
    await _close();
  }
}

/// The engine was disposed before or while a job waited.
class FrameEngineClosed implements Exception {
  const new();

  @override
  String toString() => 'FrameEngineClosed';
}

class _Waiter {
  new(this.kind, this.order);
  final FrameJob kind;
  final int order;
  final ready = Completer<void>();
}

/// A job's hold on the engine. What is configured and loaded stays between
/// jobs, so a job finding its own file still open just seeks.
class FrameSession {
  new _(this._engine, this.backend, this.scratch, {required this._ownsScratch});

  final FrameEngine _engine;
  final PlayerBackend backend;

  /// mpv's `vo-image-outdir`.
  final Directory scratch;
  final bool _ownsScratch;
  FrameJob _kind = FrameJob.probe;

  /// The options set last ([configure]).
  String? profile;

  /// What the last job left loaded, e.g. `storyboard|/v/film.mkv`; null
  /// when nothing is.
  String? loaded;

  /// A more urgent job waits: a long job should return and run again.
  bool get shouldYield => _engine._urgentWaiting(_kind);

  /// Sets [options] unless [name] is already configured. Changing profile
  /// unloads the file, since the options apply on the next load.
  Future<void> configure(String name, List<(String, String)> options) async {
    if (profile == name) return;
    for (final (k, v) in options) {
      await backend.setProperty(k, v);
    }
    profile = name;
    loaded = null;
  }

  /// Deletes pictures left in [scratch], so the next one is new.
  Future<void> clearScratch() async {
    try {
      await for (final f in scratch.list()) {
        if (f is File) await f.delete();
      }
    } on FileSystemException {
      // Being written or already gone: the next listing sees it.
    }
  }

  /// The next picture mpv writes after [clearScratch], or `same` when the
  /// seek landed where the last picture was ([lastPos], mpv draws nothing
  /// new then). Neither when [timeout] passes or [stale] becomes true.
  Future<({File? file, bool same})> nextPicture({
    required Duration timeout,
    bool Function()? stale,
    String? lastPos,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end) && !(stale?.call() ?? false)) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final file = await _picture();
      if (file != null) {
        // Let mpv finish writing it.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return (file: file, same: false);
      }
      if (lastPos != null && await backend.getProperty('seeking') == 'no') {
        if (await backend.getProperty('time-pos') == lastPos) {
          return (file: null, same: true);
        }
      }
    }
    return (file: null, same: false);
  }

  Future<File?> _picture() async {
    try {
      await for (final f in scratch.list()) {
        if (f is File && f.path.endsWith('.jpg') && f.lengthSync() > 0) {
          return f;
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }
}

/// The desktop frame engine. Phones use Android's own retriever instead.
final frameEngineProvider = Provider<FrameEngine>((ref) {
  final engine = FrameEngine(
    scratchDir: Directory(
      p.join(ref.watch(appCacheDirProvider).path, 'frame-engine'),
    ),
  );
  ref.onDispose(engine.dispose);
  return engine;
});
