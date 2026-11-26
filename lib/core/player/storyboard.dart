import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/storyboard_writer.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/cache_trim.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

/// A picture to show for a time: a whole image file, or cell [cell] of a
/// [cols]×[rows] sprite sheet (task 8.2).
@immutable
class FrameRef {
  const new(this.path, {this.cell, this.cols = 1, this.rows = 1});

  final String path;
  final int? cell;
  final int cols;
  final int rows;

  /// The part of an image of [width]×[height] pixels that is this frame.
  Rect sourceRect(double width, double height) {
    final c = cell;
    if (c == null) return Rect.fromLTWH(0, 0, width, height);
    final w = width / cols;
    final h = height / rows;
    return Rect.fromLTWH((c % cols) * w, (c ~/ cols) * h, w, h);
  }

  @override
  bool operator ==(Object other) =>
      other is FrameRef &&
      other.path == path &&
      other.cell == cell &&
      other.cols == cols &&
      other.rows == rows;

  @override
  int get hashCode => Object.hash(path, cell, cols, rows);

  @override
  String toString() =>
      cell == null ? 'FrameRef($path)' : 'FrameRef($path#$cell)';
}

/// One level of a storyboard: frames of one size, [step] apart, packed
/// [cols]×[rows] to a sheet (task 8.2). Like YouTube's storyboards: a
/// coarse level covers the whole video in one small sheet, finer levels
/// follow.
@immutable
class StoryboardLevel {
  const new({
    required this.index,
    required this.width,
    required this.step,
    required this.count,
    required this.cols,
    required this.rows,
  });

  /// 0 is the coarsest.
  final int index;

  /// Frame width in pixels (height keeps the video's shape).
  final int width;
  final Duration step;
  final int count;
  final int cols;
  final int rows;

  int get perSheet => cols * rows;
  int get sheetCount => (count / perSheet).ceil();
  int sheetOf(int frame) => frame ~/ perSheet;

  /// The frames of sheet [sheet].
  Iterable<int> framesOf(int sheet) sync* {
    final end = math.min(count, (sheet + 1) * perSheet);
    for (var i = sheet * perSheet; i < end; i++) {
      yield i;
    }
  }

  int indexAt(Duration at) =>
      (at.inMilliseconds / step.inMilliseconds).round().clamp(0, count - 1);

  Duration timeOf(int frame) => step * frame;

  /// Frames in the coarse level: enough to find a scene in any video.
  static const coarseFrames = 100;

  /// The levels for a video of [duration]. [sharp] adds 320 px frames for
  /// phones, where the preview is wide.
  static List<StoryboardLevel> forVideo(
    Duration duration, {
    bool sharp = false,
  }) {
    final ms = math.max(1, duration.inMilliseconds);
    final coarse = math.max(1, math.min(coarseFrames, (ms / 1000).ceil()));
    final step = Storyboard.stepFor(duration);
    final fine = math.max(1, (ms / step.inMilliseconds).ceil());
    return [
      StoryboardLevel(
        index: 0,
        width: 96,
        step: Duration(milliseconds: (ms / coarse).ceil()),
        count: coarse,
        cols: 10,
        rows: 10,
      ),
      StoryboardLevel(
        index: 1,
        width: 160,
        step: step,
        count: fine,
        cols: 5,
        rows: 5,
      ),
      if (sharp)
        StoryboardLevel(
          index: 2,
          width: 320,
          step: step,
          count: fine,
          cols: 5,
          rows: 5,
        ),
    ];
  }

  Map<String, Object> toJson() => {
    'width': width,
    'stepMs': step.inMilliseconds,
    'count': count,
    'cols': cols,
    'rows': rows,
  };

  bool matches(Map<Object?, Object?> json) =>
      json['width'] == width &&
      json['stepMs'] == step.inMilliseconds &&
      json['count'] == count &&
      json['cols'] == cols &&
      json['rows'] == rows;
}

/// What exists of one level: loose frame files ([tiles]), packed [sheets],
/// frames that couldn't be made ([failed]).
@immutable
class LevelFrames {
  const new(
    this.spec, {
    this.tiles = const {},
    this.sheets = const {},
    this.failed = const {},
    this.complete = false,
  });

  final StoryboardLevel spec;
  final Set<int> tiles;
  final Set<int> sheets;
  final Set<int> failed;
  final bool complete;

  bool has(int frame) =>
      tiles.contains(frame) ||
      (sheets.contains(spec.sheetOf(frame)) && !failed.contains(frame));

  /// Made, or given up on.
  bool done(int frame) => has(frame) || failed.contains(frame);

  int get ready {
    var n = tiles.length;
    for (final s in sheets) {
      n += spec.framesOf(s).where((i) => !failed.contains(i)).length;
    }
    return n;
  }

  LevelFrames copyWith({
    Set<int>? tiles,
    Set<int>? sheets,
    Set<int>? failed,
    bool? complete,
  }) => LevelFrames(
    spec,
    tiles: tiles ?? this.tiles,
    sheets: sheets ?? this.sheets,
    failed: failed ?? this.failed,
    complete: complete ?? this.complete,
  );
}

/// Frames for the whole video, made in advance so the seek bar shows the
/// scene under the finger at once, like YouTube's storyboards (tasks 7.2,
/// 8.2).
///
/// On disk, under `<cache>/storyboards/<mediaCacheKey>/`:
/// - `L<n>/s<k>.jpg`: sheet `k` of level `n`;
/// - `L<n>/tiles/<i>.jpg`: frames not packed into a sheet yet;
/// - `spec.json`: the levels, their packed sheets and failed frames.
@immutable
class Storyboard {
  const new({
    required this.source,
    required this.duration,
    required this.directory,
    required this.levels,
  });

  /// Most frames in the fine level.
  static const maxFrames = 300;

  /// The cache folder's size limit (oldest storyboards go first).
  static const int cacheLimitBytes = 500 * 1024 * 1024;

  /// Format of `spec.json`; other versions are deleted.
  static const version = 2;

  final String source;
  final Duration duration;
  final String directory;
  final List<LevelFrames> levels;

  /// One frame every 2 s up to 10 minutes, then [maxFrames] per file.
  static Duration stepFor(Duration duration) {
    if (duration <= const Duration(minutes: 10)) {
      return const Duration(seconds: 2);
    }
    return Duration(milliseconds: (duration.inMilliseconds / maxFrames).ceil());
  }

  bool get complete => levels.every((l) => l.complete);

  /// Share of frames ready, all levels together.
  double get progress {
    if (complete) return 1;
    var all = 0;
    var ready = 0;
    for (final l in levels) {
      all += l.spec.count;
      ready += l.ready + l.failed.length;
    }
    return all == 0 ? 0 : (ready / all).clamp(0.0, 1.0);
  }

  String levelDirectory(int level) => p.join(directory, 'L$level');
  String tilesDirectory(int level) => p.join(levelDirectory(level), 'tiles');
  String tilePath(int level, int frame) =>
      p.join(tilesDirectory(level), '$frame.jpg');
  String sheetPath(int level, int sheet) =>
      p.join(levelDirectory(level), 's$sheet.jpg');

  /// The picture of [frame] in [level], if it exists.
  FrameRef? frame(int level, int frame) {
    final l = levels[level];
    if (l.tiles.contains(frame)) return FrameRef(tilePath(level, frame));
    final sheet = l.spec.sheetOf(frame);
    if (l.sheets.contains(sheet) && !l.failed.contains(frame)) {
      return FrameRef(
        sheetPath(level, sheet),
        cell: frame % l.spec.perSheet,
        cols: l.spec.cols,
        rows: l.spec.rows,
      );
    }
    return null;
  }

  /// The best picture for [at]: the finest level that has that very frame,
  /// else the nearest frame of the coarsest level that has any. Null
  /// before any frame exists. [maxLevel] skips sharper levels.
  FrameRef? nearest(Duration at, {int? maxLevel}) {
    final top = math.min(levels.length - 1, maxLevel ?? levels.length - 1);
    for (var level = top; level >= 0; level--) {
      final f = frame(level, levels[level].spec.indexAt(at));
      if (f != null) return f;
    }
    for (var level = 0; level <= top; level++) {
      final l = levels[level];
      final want = l.spec.indexAt(at);
      for (var d = 1; d < l.spec.count; d++) {
        final f = frame(level, want - d) ?? frame(level, want + d);
        if (f != null) return f;
        if (want - d < 0 && want + d >= l.spec.count) break;
      }
    }
    return null;
  }

  Storyboard withLevel(LevelFrames level) => Storyboard(
    source: source,
    duration: duration,
    directory: directory,
    levels: [
      for (final l in levels)
        if (l.spec.index == level.spec.index) level else l,
    ],
  );

  /// The folder for [source] under [cacheDir]. The key includes a local
  /// file's size and modified time (task 8.0).
  static String directoryFor(Directory cacheDir, String source) =>
      p.join(cacheDir.path, 'storyboards', mediaCacheKey(source));

  /// What is on disk for [source]. Folders of another format (the 7.2
  /// one-file-per-frame storyboards) are deleted.
  static Storyboard read(
    Directory cacheDir,
    String source,
    Duration duration, {
    bool sharp = false,
  }) {
    final dir = directoryFor(cacheDir, source);
    final specs = StoryboardLevel.forVideo(duration, sharp: sharp);
    var board = Storyboard(
      source: source,
      duration: duration,
      directory: dir,
      levels: [for (final s in specs) LevelFrames(s)],
    );
    final folder = Directory(dir);
    if (!folder.existsSync()) return board;
    Map<Object?, Object?>? json;
    final spec = File(p.join(dir, 'spec.json'));
    try {
      if (spec.existsSync()) {
        json = jsonDecode(spec.readAsStringSync()) as Map<Object?, Object?>;
      }
    } on Object {
      json = null;
    }
    if (json == null || json['version'] != version) {
      // Another format (7.2 wrote `<i>.jpg` and `index.json` here): start
      // again. No spec yet is a first render still writing tiles.
      final oldFormat =
          json != null ||
          folder.listSync().any(
            (e) => e is File && p.basename(e.path) != 'spec.json.part',
          );
      if (oldFormat) {
        try {
          folder.deleteSync(recursive: true);
        } on FileSystemException {
          // In use: tried again next time.
        }
        return board;
      }
    }
    final saved = (json?['levels'] as Map<Object?, Object?>?) ?? const {};
    for (final s in specs) {
      final j = saved['${s.index}'] as Map<Object?, Object?>?;
      Set<int> ints(String key) => {
        for (final v in (j?[key] as List<Object?>?) ?? const [])
          (v! as num).toInt(),
      };
      final known = j != null && s.matches(j);
      final tiles = <int>{};
      final tilesDir = Directory(board.tilesDirectory(s.index));
      if (tilesDir.existsSync()) {
        for (final f in tilesDir.listSync()) {
          final i = f.path.endsWith('.jpg')
              ? int.tryParse(p.basenameWithoutExtension(f.path))
              : null;
          if (i != null && i < s.count) tiles.add(i);
        }
      }
      board = board.withLevel(
        LevelFrames(
          s,
          tiles: tiles,
          sheets: known ? ints('sheets') : const {},
          failed: known ? ints('failed') : const {},
          complete: known && j['complete'] == true,
        ),
      );
    }
    return board;
  }

  /// Saves the levels' sheets, failed frames and completeness.
  void writeSpec() {
    Directory(directory).createSync(recursive: true);
    File(p.join(directory, 'spec.json.part'))
      ..writeAsStringSync(jsonEncode(_specJson()))
      ..renameSync(p.join(directory, 'spec.json'));
  }

  Map<String, Object> _specJson() => {
    'version': version,
    'source': source,
    'durationMs': duration.inMilliseconds,
    'levels': {
      for (final l in levels)
        '${l.spec.index}': {
          ...l.spec.toJson(),
          'sheets': (l.sheets.toList()..sort()),
          'failed': (l.failed.toList()..sort()),
          'complete': l.complete,
        },
    },
  };

  /// Whether a level with [failed] frames out of [count] is good enough to
  /// keep. More than 1 in 10 missing is probably a passing problem (slow
  /// disk, busy decoder): leave it unfinished to retry.
  static bool acceptable(int count, Set<int> failed) =>
      failed.length <= count ~/ 10;

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

/// Frame indexes 0…[count]-1, coarse to fine: 0, then the middle, the
/// quarters, the eighths… so a partial storyboard already covers the whole
/// video (task 8.2).
List<int> coarseToFine(int count) {
  if (count <= 0) return const [];
  var stride = 1;
  while (stride < count) {
    stride *= 2;
  }
  final seen = List<bool>.filled(count, false);
  final out = <int>[];
  for (; stride >= 1; stride ~/= 2) {
    for (var i = 0; i < count; i += stride) {
      if (!seen[i]) {
        seen[i] = true;
        out.add(i);
      }
    }
  }
  return out;
}

/// The size limit of `<cache>/previews` (seek-bar and library frames).
const int previewCacheLimitBytes = 200 * 1024 * 1024;

/// Trims the storyboard and preview caches (task 8.0), keeping [keep].
/// [storyboardBytes] is the user's cache size (task 8.4).
Future<void> trimFrameCaches(
  Directory cacheDir, {
  String? keep,
  int storyboardBytes = Storyboard.cacheLimitBytes,
}) async {
  await Storyboard.trimCache(cacheDir, keep: keep, limit: storyboardBytes);
  final previews = p.join(cacheDir.path, 'previews');
  await trimCacheFolder(
    Directory(previews),
    limit: previewCacheLimitBytes,
    keep: {p.join(previews, 'scratch')},
  );
}

/// Makes the frames of a [Storyboard] into its folder.
abstract interface class StoryboardSource {
  /// Makes the missing frames of [board]'s levels, coarse level first, and
  /// completes when done (levels up to [maxLevel] when given); false if it
  /// failed or was cancelled. [onChange] gets the board after every frame
  /// and sheet.
  Future<bool> render(
    Storyboard board, {
    void Function(Storyboard board)? onChange,
    int? maxLevel,
  });

  /// Frames near [at] are wanted now (the finger is there).
  void focus(Duration at);

  /// Stops [render] early.
  Future<void> cancel();
}

/// Desktop: the shared [FrameEngine] opens the file once per level, paused,
/// and seeks to each frame (keyframe seeks: fast); `vo=image` writes one
/// picture per seek. When a more urgent frame is wanted (the finger rests
/// on the seek bar), the render hands the engine over and carries on
/// afterwards (tasks 7.2, 8.1, 8.2).
class MpvStoryboardSource implements StoryboardSource {
  /// [engine] is shared in the app; tests may pass [backendFactory] for an
  /// engine of their own.
  new({
    FrameEngine? engine,
    PlayerBackend Function()? backendFactory,
    this.job = FrameJob.storyboard,
  }) : _engine = engine ?? FrameEngine(backendFactory: backendFactory),
       _ownsEngine = engine == null;

  /// The engine priority of this source's work: library previews run as
  /// [FrameJob.probe], after the playing file's storyboard (task 8.4).
  final FrameJob job;

  /// How long one seek may take before that frame is skipped.
  static const frameTimeout = Duration(seconds: 3);

  /// Options of a level's profile.
  static List<(String, String)> optionsFor(StoryboardLevel level) => [
    ('vo', 'image'),
    ('vid', 'auto'),
    ('aid', 'no'),
    ('vo-image-jpeg-quality', '80'),
    ('vf', 'scale=w=${level.width}:h=-2'),
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
  StoryboardWriter? _writer;

  @override
  void focus(Duration at) => _writer?.focus = at;

  @override
  Future<bool> render(
    Storyboard board, {
    void Function(Storyboard board)? onChange,
    int? maxLevel,
  }) async {
    final token = ++_generation;
    final previous = _last;
    final done = Completer<void>();
    _last = done.future;
    try {
      await previous;
      if (token != _generation) return false;
      final writer = _writer = StoryboardWriter(board, onChange: onChange);
      return await _render(writer, () => token != _generation, maxLevel);
    } on FrameEngineClosed {
      return false;
    } finally {
      done.complete();
    }
  }

  Future<bool> _render(
    StoryboardWriter writer,
    bool Function() stale,
    int? maxLevel,
  ) async {
    final levels = _levels(writer.board, maxLevel);
    for (final level in levels) {
      if (level.complete) continue;
      final n = level.spec.index;
      await Directory(writer.board.tilesDirectory(n)).create(recursive: true);
      while (true) {
        if (stale()) return false;
        final r = await _engine.run(job, (s) => _chunk(s, writer, n, stale));
        if (r == _Chunk.unreadable) return false;
        if (r == _Chunk.levelDone) break;
      }
      await writer.finishLevel(n);
    }
    await writer.flush();
    return !stale() && _levels(writer.board, maxLevel).every((l) => l.complete);
  }

  static Iterable<LevelFrames> _levels(Storyboard b, int? maxLevel) =>
      b.levels.where((l) => maxLevel == null || l.spec.index <= maxLevel);

  /// Makes frames of [level] until it is done, cancelled, or a more urgent
  /// job waits.
  Future<_Chunk> _chunk(
    FrameSession s,
    StoryboardWriter writer,
    int level,
    bool Function() stale,
  ) async {
    final b = s.backend;
    final board = writer.board;
    final spec = board.levels[level].spec;
    final tag = 'storyboard|L$level|${board.source}';
    var i = writer.next(level);
    if (i == null) return _Chunk.levelDone;
    var loaded = false;
    try {
      if (s.loaded != tag) {
        await s.configure('storyboard-L$level', optionsFor(spec));
        await s.clearScratch();
        await b.setProperty('start', _seconds(spec.timeOf(i)));
        await b.command(['loadfile', board.source, 'replace']);
        s.loaded = tag;
        loaded = true; // The first picture is frame i.
      }
      String? lastPos;
      String? lastTile;
      while (i != null) {
        if (stale()) {
          await b.command(['stop']);
          s.loaded = null;
          return _Chunk.yielded;
        }
        if (s.shouldYield) return _Chunk.yielded;
        final frame = i;
        if (!loaded) {
          await s.clearScratch();
          await b.command([
            'seek',
            _seconds(spec.timeOf(frame)),
            'absolute+keyframes',
          ]);
        }
        final firstAfterLoad = loaded;
        loaded = false;
        final next = await s.nextPicture(
          timeout: frameTimeout,
          stale: stale,
          lastPos: lastPos,
        );
        final tile = board.tilePath(level, frame);
        final picture = next.file;
        if (picture != null) {
          await picture.rename(tile);
          lastTile = tile;
          lastPos = await b.getProperty('time-pos');
          writer.tileWritten(level, frame);
        } else if (next.same && lastTile != null) {
          // The seek landed on the keyframe already shown: same picture.
          await File(lastTile).copy(tile);
          writer.tileWritten(level, frame);
        } else if (stale()) {
          continue; // Stopped, not failed: the top of the loop returns.
        } else if (firstAfterLoad && _nothingYet(writer.board)) {
          s.loaded = null;
          return _Chunk.unreadable; // The file didn't open.
        } else {
          writer.tileFailed(level, frame);
        }
        i = writer.next(level);
      }
      return _Chunk.levelDone;
    } on FileSystemException {
      s.loaded = null;
      return _Chunk.unreadable;
    }
  }

  static bool _nothingYet(Storyboard b) =>
      b.levels.every((l) => l.tiles.isEmpty && l.sheets.isEmpty);

  static String _seconds(Duration d) => '${d.inMilliseconds / 1000}';

  @override
  Future<void> cancel() async => _generation++;

  Future<void> dispose() async {
    _generation++;
    if (_ownsEngine) await _engine.dispose();
  }
}

enum _Chunk { levelDone, yielded, unreadable }

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

  /// Least time between two screen updates while frames arrive.
  static const updateInterval = Duration(milliseconds: 250);

  String? _for;
  Timer? _start;
  Timer? _update;
  Storyboard? _pending;
  Completer<void>? _shown;
  late StoryboardSource _source;

  @override
  Storyboard? build() {
    final service = ref.watch(playerServiceProvider);
    _source = ref.watch(storyboardSourceProvider);
    ref.read(windowServiceProvider)
      ..onHidden(() async => _shown ??= Completer<void>())
      ..onShown(() async {
        _shown?.complete();
        _shown = null;
      });
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
      _update?.cancel();
      if (_for != null) unawaited(_source.cancel());
      _for = null;
      unawaited(sub.cancel());
    });
    return null;
  }

  /// The user is looking at [at]: frames near it are made first.
  void focus(Duration at) => _source.focus(at);

  static bool _isStream(String source) =>
      source.contains('://') &&
      !source.startsWith('file://') &&
      !source.startsWith('content://');

  void _stop() {
    _start?.cancel();
    _update?.cancel();
    _update = null;
    _pending = null;
    if (_for != null) unawaited(_source.cancel());
    _for = null;
    state = null;
  }

  Future<void> _make(String source, Duration duration) async {
    final cache = ref.read(appCacheDirProvider);
    final sharp = ref.read(platformCapabilitiesProvider).isMobile;
    final board = Storyboard.read(cache, source, duration, sharp: sharp);
    state = board;
    if (board.complete) return;
    // Nothing is made while the window is hidden.
    while (_shown != null && _for == source) {
      await _shown!.future;
    }
    if (_for != source) return;
    // In the background: trimming lists every cached file.
    final mb = ref.read(settingsProvider).frameCacheMb;
    unawaited(
      trimFrameCaches(
        cache,
        keep: board.directory,
        storyboardBytes: mb * 1024 * 1024,
      ),
    );
    final ok = await _source.render(
      board,
      onChange: (b) {
        if (_for != source) return;
        // Frames arrive quickly: the screen updates a few times a second.
        _pending = b;
        _update ??= Timer(updateInterval, () {
          _update = null;
          final pending = _pending;
          if (pending != null && _for == source) state = pending;
        });
      },
    );
    if (_for != source) return;
    _update?.cancel();
    _update = null;
    final last = _pending ?? state;
    _pending = null;
    if (last != null) state = last;
    if (!ok) return; // Tried again the next time the file opens.
  }
}

final storyboardProvider = NotifierProvider<StoryboardController, Storyboard?>(
  StoryboardController.new,
);
