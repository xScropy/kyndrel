import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/cache_trim.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

/// Frames for the whole video, made in advance so the seek bar can show the
/// scene under the finger at once, like YouTube's storyboards (task 7.2).
///
/// Frame `i` shows the time `i * step`. Frames are small JPEGs in
/// `<cache>/storyboards/<hash of source>/<i>.jpg`, with `index.json` once
/// all of them are written.
@immutable
class Storyboard {
  const new({
    required this.source,
    required this.duration,
    required this.step,
    required this.directory,
    this.available = const {},
    this.complete = false,
  });

  /// Frame width in pixels.
  static const width = 160;

  /// Most frames per file.
  static const maxFrames = 300;

  /// The cache folder's size limit (oldest storyboards go first).
  static const int cacheLimitBytes = 500 * 1024 * 1024;

  final String source;
  final Duration duration;
  final Duration step;
  final String directory;

  /// Indexes of the frames written so far.
  final Set<int> available;
  final bool complete;

  /// One frame every 2 s up to 10 minutes, then [maxFrames] per file.
  static Duration stepFor(Duration duration) {
    if (duration <= const Duration(minutes: 10)) {
      return const Duration(seconds: 2);
    }
    return Duration(milliseconds: (duration.inMilliseconds / maxFrames).ceil());
  }

  int get count =>
      math.max(1, (duration.inMilliseconds / step.inMilliseconds).ceil());

  double get progress =>
      complete ? 1 : (available.length / count).clamp(0.0, 1.0);

  String pathOf(int index) => p.join(directory, '$index.jpg');

  /// The written frame nearest to [at], or null if there is none yet.
  String? nearest(Duration at) {
    if (available.isEmpty) return null;
    final want = (at.inMilliseconds / step.inMilliseconds).round().clamp(
      0,
      count - 1,
    );
    if (available.contains(want)) return pathOf(want);
    // Nearest written frame, searching outward.
    for (var d = 1; d < count; d++) {
      if (available.contains(want - d)) return pathOf(want - d);
      if (available.contains(want + d)) return pathOf(want + d);
    }
    return null;
  }

  Storyboard copyWith({Set<int>? available, bool? complete}) => Storyboard(
    source: source,
    duration: duration,
    step: step,
    directory: directory,
    available: available ?? this.available,
    complete: complete ?? this.complete,
  );

  /// The folder for [source] under [cacheDir]. The key includes a local
  /// file's size and modified time (task 8.0).
  static String directoryFor(Directory cacheDir, String source) =>
      p.join(cacheDir.path, 'storyboards', mediaCacheKey(source));

  /// What is on disk for [source]: written frames, and whether the set is
  /// complete for this length.
  ///
  /// Complete means `index.json` matches this spacing and frame count, and
  /// every frame is either written or recorded as failed.
  static Storyboard read(Directory cacheDir, String source, Duration duration) {
    final dir = directoryFor(cacheDir, source);
    final board = Storyboard(
      source: source,
      duration: duration,
      step: stepFor(duration),
      directory: dir,
    );
    final folder = Directory(dir);
    if (!folder.existsSync()) return board;
    final frames = <int>{};
    for (final f in folder.listSync().whereType<File>()) {
      final i = _frameIndex(f.path);
      if (i != null) frames.add(i);
    }
    var complete = false;
    final index = File(p.join(dir, 'index.json'));
    if (index.existsSync()) {
      try {
        final json = jsonDecode(index.readAsStringSync()) as Map;
        final failed = {
          for (final f in (json['failed'] as List?) ?? const <Object>[])
            (f as num).toInt(),
        };
        complete =
            json['stepMs'] == board.step.inMilliseconds &&
            json['count'] == board.count &&
            Iterable<int>.generate(board.count)
                .every((i) => frames.contains(i) || failed.contains(i));
      } on Object {
        complete = false;
      }
    }
    return board.copyWith(available: frames, complete: complete);
  }

  /// `7.jpg` → 7; anything else (`7.part`, `index.json`) → null.
  static int? _frameIndex(String path) => path.endsWith('.jpg')
      ? int.tryParse(p.basenameWithoutExtension(path))
      : null;

  /// The frames written in [directory] (async: for background work).
  static Future<Set<int>> framesOnDisk(String directory) async {
    final out = <int>{};
    final dir = Directory(directory);
    if (!dir.existsSync()) return out;
    await for (final f in dir.list()) {
      final i = f is File ? _frameIndex(f.path) : null;
      if (i != null) out.add(i);
    }
    return out;
  }

  /// Whether a finished render with [failed] frames out of [count] is good
  /// enough to keep. More than 1 in 10 missing is probably a passing
  /// problem (slow disk, busy decoder): leave it unfinished to retry.
  static bool acceptable(int count, Set<int> failed) =>
      failed.length <= count ~/ 10;

  /// Marks the frames as complete; [failed] frames couldn't be made and
  /// aren't retried.
  void writeIndex({Set<int> failed = const {}}) {
    File(p.join(directory, 'index.json')).writeAsStringSync(
      jsonEncode({
        'source': source,
        'stepMs': step.inMilliseconds,
        'count': count,
        'failed': (failed.toList()..sort()),
      }),
    );
  }

  /// Deletes the oldest storyboards until the folder is under [limit],
  /// keeping [keep] (the one in use).
  static Future<void> trimCache(
    Directory cacheDir, {
    int limit = cacheLimitBytes,
    String? keep,
  }) => trimCacheFolder(
    Directory(p.join(cacheDir.path, 'storyboards')),
    limit: limit,
    keep: {?keep},
  );
}

/// The size limit of `<cache>/previews` (seek-bar and library frames).
const int previewCacheLimitBytes = 200 * 1024 * 1024;

/// Trims the storyboard and preview caches (task 8.0), keeping [keep].
Future<void> trimFrameCaches(Directory cacheDir, {String? keep}) async {
  await Storyboard.trimCache(cacheDir, keep: keep);
  final previews = p.join(cacheDir.path, 'previews');
  await trimCacheFolder(
    Directory(previews),
    limit: previewCacheLimitBytes,
    keep: {p.join(previews, 'scratch')},
  );
}

/// Makes the frames of a [Storyboard] into its folder.
abstract interface class StoryboardSource {
  /// Writes frames into [board]'s folder (skipping ones already there)
  /// and completes when done; false if it failed or was cancelled.
  Future<bool> render(Storyboard board);

  /// Stops [render] early.
  Future<void> cancel();
}

/// Desktop: the shared [FrameEngine] opens the file once, paused, and
/// seeks to each step (keyframe seeks: fast). `vo=image` writes one picture
/// per seek. When a more urgent frame is wanted (the finger rests on the
/// seek bar), the render hands the engine over and carries on afterwards
/// from the frame it reached (task 8.1).
class MpvStoryboardSource implements StoryboardSource {
  /// [engine] is shared in the app; tests may pass [backendFactory] for an
  /// engine of their own.
  new({FrameEngine? engine, PlayerBackend Function()? backendFactory})
    : _engine = engine ?? FrameEngine(backendFactory: backendFactory),
      _ownsEngine = engine == null;

  /// How long one seek may take before that frame is skipped.
  static const frameTimeout = Duration(seconds: 3);

  /// Options of the storyboard profile.
  static const options = [
    ('vo', 'image'),
    ('vid', 'auto'),
    ('aid', 'no'),
    ('vo-image-jpeg-quality', '70'),
    ('vf', 'scale=w=${Storyboard.width}:h=-2'),
    ('hr-seek', 'no'),
  ];

  final FrameEngine _engine;
  final bool _ownsEngine;

  /// Each render gets a number; [cancel] and newer renders bump it, so an
  /// old render still waiting stops instead of sharing the engine with the
  /// new one (task 8.0).
  int _generation = 0;

  /// Renders run one after another.
  Future<void> _last = Future.value();

  @override
  Future<bool> render(Storyboard board) async {
    final token = ++_generation;
    final previous = _last;
    final done = Completer<void>();
    _last = done.future;
    try {
      await previous;
      if (token != _generation) return false;
      return await _render(board, () => token != _generation);
    } on FrameEngineClosed {
      return false;
    } finally {
      done.complete();
    }
  }

  Future<bool> _render(Storyboard board, bool Function() stale) async {
    await Directory(board.directory).create(recursive: true);
    final have = await Storyboard.framesOnDisk(board.directory);
    final failed = <int>{};
    var next = 0;
    while (next < board.count) {
      final reached = await _engine.run(
        FrameJob.storyboard,
        (s) => _chunk(s, board, next, have, failed, stale),
      );
      if (reached == null || stale()) return false;
      next = reached;
    }
    if (have.isEmpty || !Storyboard.acceptable(board.count, failed)) {
      return false;
    }
    board.writeIndex(failed: failed);
    return true;
  }

  /// Renders frames from [from] on, until the end, a cancel, or a more
  /// urgent job; returns the frame to continue from, or null when the file
  /// won't open.
  Future<int?> _chunk(
    FrameSession s,
    Storyboard board,
    int from,
    Set<int> have,
    Set<int> failed,
    bool Function() stale,
  ) async {
    final b = s.backend;
    var i = from;
    while (i < board.count && have.contains(i)) {
      i++;
    }
    if (i >= board.count) return board.count;
    final tag = 'storyboard|${board.source}';
    var seek = true;
    try {
      if (s.loaded != tag) {
        await s.configure('storyboard', options);
        await s.clearScratch();
        await b.setProperty('start', _seconds(board.step * i));
        await b.command(['loadfile', board.source, 'replace']);
        s.loaded = tag;
        seek = false; // The first picture is frame i.
      }
      String? lastPos;
      for (; i < board.count; i++) {
        if (stale()) {
          await b.command(['stop']);
          s.loaded = null;
          return i;
        }
        if (have.contains(i)) {
          seek = true;
          continue;
        }
        if (s.shouldYield) return i;
        if (seek) {
          await s.clearScratch();
          await b.command([
            'seek',
            _seconds(board.step * i),
            'absolute+keyframes',
          ]);
        }
        seek = true;
        final next = await s.nextPicture(
          timeout: frameTimeout,
          stale: stale,
          lastPos: lastPos,
        );
        final picture = next.file;
        if (picture != null) {
          await picture.rename(board.pathOf(i));
          have.add(i);
          lastPos = await b.getProperty('time-pos');
        } else if (next.same && have.contains(i - 1)) {
          // Same keyframe as the step before: the same picture.
          await File(board.pathOf(i - 1)).copy(board.pathOf(i));
          have.add(i);
        } else if (stale()) {
          continue; // Stopped, not failed: the top of the loop returns.
        } else if (i == from && lastPos == null && have.isEmpty) {
          s.loaded = null;
          return null; // The file didn't open.
        } else {
          failed.add(i);
        }
      }
      return board.count;
    } on Object {
      s.loaded = null;
      return null;
    }
  }

  static String _seconds(Duration d) => '${d.inMilliseconds / 1000}';

  @override
  Future<void> cancel() async => _generation++;

  Future<void> dispose() async {
    _generation++;
    if (_ownsEngine) await _engine.dispose();
  }
}

final storyboardSourceProvider = Provider<StoryboardSource>((ref) {
  final s = MpvStoryboardSource(engine: ref.watch(frameEngineProvider));
  ref.onDispose(s.dispose);
  return s;
});

/// The storyboard of the file playing now, growing while it is made; null
/// for streams, audio and before a file has loaded.
class StoryboardController extends Notifier<Storyboard?> {
  /// How long a file plays before its storyboard starts.
  static const delay = Duration(seconds: 2);

  String? _for;
  Timer? _start;
  Timer? _poll;
  bool _hidden = false;
  late StoryboardSource _source;

  @override
  Storyboard? build() {
    final service = ref.watch(playerServiceProvider);
    _source = ref.watch(storyboardSourceProvider);
    ref.read(windowServiceProvider)
      ..onHidden(() async => _hidden = true)
      ..onShown(() async => _hidden = false);
    // A direct subscription: provider listeners are paused while nothing
    // watches this provider.
    final sub = service.states.listen((s) {
      final source = s.source;
      final local = source != null && !_isStream(source);
      final ready =
          local &&
          s.isLoaded &&
          s.duration > Duration.zero &&
          s.videoWidth != null;
      if (!ready) {
        if (source != _for) _stop();
        return;
      }
      if (source == _for) return;
      _stop();
      _for = source;
      _start = Timer(delay, () => unawaited(_make(source, s.duration)));
    });
    ref.onDispose(() {
      _start?.cancel();
      _poll?.cancel();
      if (_for != null) unawaited(_source.cancel());
      _for = null;
      unawaited(sub.cancel());
    });
    return null;
  }

  static bool _isStream(String source) =>
      source.contains('://') &&
      !source.startsWith('file://') &&
      !source.startsWith('content://');

  void _stop() {
    _start?.cancel();
    _poll?.cancel();
    if (_for != null) unawaited(_source.cancel());
    _for = null;
    state = null;
  }

  Future<void> _make(String source, Duration duration) async {
    final cache = ref.read(appCacheDirProvider);
    var board = Storyboard.read(cache, source, duration);
    state = board;
    if (board.complete) return;
    while (_hidden && _for == source) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (_for != source) return;
    // In the background: trimming lists every cached file.
    unawaited(trimFrameCaches(cache, keep: board.directory));
    // Shows frames as they appear.
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_for != source) return;
      board = Storyboard.read(cache, source, duration);
      state = board;
    });
    final ok = await _source.render(board);
    _poll?.cancel();
    if (_for != source) return;
    state = Storyboard.read(cache, source, duration).copyWith(complete: ok);
  }
}

final storyboardProvider = NotifierProvider<StoryboardController, Storyboard?>(
  StoryboardController.new,
);
