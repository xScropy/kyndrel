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
import 'package:kyndrel/core/utils/hashing.dart';
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

  /// The folder for [source] under [cacheDir].
  static String directoryFor(Directory cacheDir, String source) =>
      p.join(cacheDir.path, 'storyboards', fnv1a64(source));

  /// What is on disk for [source]: written frames, and whether the set is
  /// complete for this length.
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
      final name = p.basenameWithoutExtension(f.path);
      final i = int.tryParse(name);
      if (i != null && f.path.endsWith('.jpg')) frames.add(i);
    }
    var complete = false;
    final index = File(p.join(dir, 'index.json'));
    if (index.existsSync()) {
      try {
        final json = jsonDecode(index.readAsStringSync()) as Map;
        complete = json['stepMs'] == board.step.inMilliseconds;
      } on Object {
        complete = false;
      }
    }
    return board.copyWith(available: frames, complete: complete);
  }

  /// Marks the frames as complete.
  void writeIndex() {
    File(p.join(directory, 'index.json')).writeAsStringSync(
      jsonEncode({
        'source': source,
        'stepMs': step.inMilliseconds,
        'count': count,
      }),
    );
  }

  /// Deletes the oldest storyboards until the folder is under [limit],
  /// keeping [keep] (the one in use).
  static void trimCache(
    Directory cacheDir, {
    int limit = cacheLimitBytes,
    String? keep,
  }) {
    final root = Directory(p.join(cacheDir.path, 'storyboards'));
    if (!root.existsSync()) return;
    final boards = <(Directory, int, DateTime)>[];
    var total = 0;
    for (final d in root.listSync().whereType<Directory>()) {
      var size = 0;
      var newest = DateTime.fromMillisecondsSinceEpoch(0);
      for (final f in d.listSync().whereType<File>()) {
        final stat = f.statSync();
        size += stat.size;
        if (stat.modified.isAfter(newest)) newest = stat.modified;
      }
      total += size;
      boards.add((d, size, newest));
    }
    boards.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (dir, size, _) in boards) {
      if (total <= limit) break;
      if (dir.path == keep) continue;
      dir.deleteSync(recursive: true);
      total -= size;
    }
  }
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
  bool _cancelled = false;

  @override
  Future<bool> render(Storyboard board) async {
    _cancelled = false;
    final scratch = Directory('${board.directory}.part');
    try {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      scratch.createSync(recursive: true);
      Directory(board.directory).createSync(recursive: true);
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
      // The first picture (time 0) arrives once the file has opened.
      var seen = 0;
      String? lastPos;

      /// The picture this seek produced; `null` with [same] when it landed
      /// on the keyframe already shown (mpv draws nothing new then).
      Future<({File? frame, bool same})> nextFrame() async {
        final end = DateTime.now().add(frameTimeout);
        while (DateTime.now().isBefore(end) && !_cancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          final files = _frames(scratch);
          if (files.length > seen) {
            seen = files.length;
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

      var written = 0;
      for (var i = 0; i < board.count; i++) {
        if (_cancelled) {
          await b.command(['stop']);
          return false;
        }
        final out = File(board.pathOf(i));
        if (i > 0) {
          if (out.existsSync()) continue;
          final at = (board.step * i).inMilliseconds / 1000;
          await b.command(['seek', '$at', 'absolute+keyframes']);
        }
        final next = await nextFrame();
        final frame = next.frame;
        if (frame != null) {
          if (out.existsSync()) {
            frame.deleteSync();
          } else {
            frame.renameSync(out.path);
          }
          written++;
        } else if (next.same && i > 0) {
          // Same keyframe as the step before: the same picture.
          final previous = File(board.pathOf(i - 1));
          if (previous.existsSync()) {
            previous.copySync(out.path);
            written++;
          }
        } else if (i == 0) {
          return false; // The file didn't open.
        }
      }
      await b.command(['stop']);
      if (written == 0) return false;
      board.writeIndex();
      return true;
    } on Object {
      return false;
    } finally {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    }
  }

  /// mpv's pictures so far (00000001.jpg, …), oldest first.
  static List<File> _frames(Directory scratch) =>
      scratch
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  @override
  Future<void> cancel() async => _cancelled = true;

  Future<void> dispose() async {
    _cancelled = true;
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
    Storyboard.trimCache(cache, keep: board.directory);
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
