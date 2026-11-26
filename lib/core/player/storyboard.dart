import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
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

/// Desktop: a hidden second mpv opens the file once, paused, and seeks to
/// each step (keyframe seeks: fast). `vo=image` writes one picture per
/// seek, so each file's index is known. Much faster than one `loadfile`
/// per frame (3.7).
class MpvStoryboardSource implements StoryboardSource {
  new({PlayerBackend Function()? backendFactory})
    : _factory = backendFactory ?? (() => MediaKitBackend(withVideo: false));

  /// How long one seek may take before that frame is skipped.
  static const frameTimeout = Duration(seconds: 3);

  final PlayerBackend Function() _factory;
  PlayerBackend? _backend;

  /// Each render gets a number; [cancel] and newer renders bump it, so an
  /// old render still waiting on mpv stops instead of sharing the backend
  /// with the new one (task 8.0).
  int _generation = 0;

  /// Renders run one after another on the single backend.
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
    } finally {
      done.complete();
    }
  }

  Future<bool> _render(Storyboard board, bool Function() stale) async {
    final scratch = Directory('${board.directory}.part');
    try {
      if (scratch.existsSync()) await scratch.delete(recursive: true);
      await scratch.create(recursive: true);
      await Directory(board.directory).create(recursive: true);
      final b = _backend ??= _factory();
      for (final (k, v) in [
        ('ao', 'null'),
        ('aid', 'no'),
        ('sid', 'no'),
        ('vid', 'auto'),
        ('hwdec', 'no'),
        ('vo', 'image'),
        ('vo-image-format', 'jpg'),
        ('vo-image-jpeg-quality', '70'),
        ('vo-image-outdir', scratch.path),
        ('vf', 'scale=w=${Storyboard.width}:h=-2'),
        ('hr-seek', 'no'),
        ('keep-open', 'always'),
        ('pause', 'yes'),
        ('start', '0'),
      ]) {
        await b.setProperty(k, v);
      }
      await b.command(['loadfile', board.source, 'replace']);
      // The first picture (time 0) arrives once the file has opened. mpv
      // numbers its pictures (00000001.jpg, …) and each is moved out as
      // soon as it is seen, so a new picture is one with a later name.
      var newest = '';
      String? lastPos;

      /// The picture this seek produced; `null` with [same] when it landed
      /// on the keyframe already shown (mpv draws nothing new then).
      Future<({File? frame, bool same})> nextFrame() async {
        final end = DateTime.now().add(frameTimeout);
        while (DateTime.now().isBefore(end) && !stale()) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          final files = (await _frames(scratch))
              .where((f) => p.basename(f.path).compareTo(newest) > 0)
              .toList();
          if (files.isNotEmpty) {
            newest = p.basename(files.last.path);
            // Let mpv finish writing it.
            await Future<void>.delayed(const Duration(milliseconds: 10));
            lastPos = await b.getProperty('time-pos');
            return (frame: files.last, same: false);
          }
          if (lastPos != null && await b.getProperty('seeking') == 'no') {
            final pos = await b.getProperty('time-pos');
            if (pos == lastPos) return (frame: null, same: true);
          }
        }
        return (frame: null, same: false);
      }

      final have = await Storyboard.framesOnDisk(board.directory);
      final failed = <int>{};
      for (var i = 0; i < board.count; i++) {
        if (stale()) {
          await b.command(['stop']);
          return false;
        }
        if (i > 0) {
          if (have.contains(i)) continue;
          final at = (board.step * i).inMilliseconds / 1000;
          await b.command(['seek', '$at', 'absolute+keyframes']);
        }
        final out = board.pathOf(i);
        final next = await nextFrame();
        final frame = next.frame;
        if (frame != null) {
          if (have.contains(i)) {
            await frame.delete();
          } else {
            await frame.rename(out);
          }
          have.add(i);
        } else if (next.same && have.contains(i - 1)) {
          // Same keyframe as the step before: the same picture.
          await File(board.pathOf(i - 1)).copy(out);
          have.add(i);
        } else if (i == 0 && !have.contains(0)) {
          return false; // The file didn't open.
        } else if (!have.contains(i)) {
          if (stale()) continue; // Stopped, not failed: the loop returns.
          failed.add(i);
        }
      }
      await b.command(['stop']);
      if (have.isEmpty || !Storyboard.acceptable(board.count, failed)) {
        return false;
      }
      board.writeIndex(failed: failed);
      return true;
    } on Object {
      return false;
    } finally {
      if (scratch.existsSync()) await scratch.delete(recursive: true);
    }
  }

  /// mpv's pictures so far (00000001.jpg, …), oldest first.
  static Future<List<File>> _frames(Directory scratch) async {
    final files = <File>[];
    await for (final f in scratch.list()) {
      if (f is File && f.path.endsWith('.jpg')) files.add(f);
    }
    return files..sort((a, b) => a.path.compareTo(b.path));
  }

  @override
  Future<void> cancel() async => _generation++;

  Future<void> dispose() async {
    _generation++;
    await _backend?.dispose();
  }
}

final storyboardSourceProvider = Provider<StoryboardSource>((ref) {
  final s = MpvStoryboardSource();
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
