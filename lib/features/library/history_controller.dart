import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:path/path.dart' as p;

/// Records what was played, how far, and a thumbnail (task 3.3).
class HistoryController extends Notifier<void> {
  static const saveInterval = Duration(seconds: 30);

  /// A thumbnail is (re)taken at most this often while playing.
  static const thumbnailInterval = Duration(minutes: 2);

  /// First thumbnail once playback has run this long (skips black intros).
  static const firstThumbnailAfter = Duration(seconds: 20);

  PlaybackState _last = PlaybackState.initial;
  String? _recordedSource;
  DateTime? _lastThumbnail;
  String? _thumbnail;
  Timer? _timer;

  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  @override
  void build() {
    final sub = ref.watch(playerServiceProvider).states.listen(_onState);
    ref.onDispose(() {
      unawaited(sub.cancel());
      _timer?.cancel();
    });
  }

  static String titleFor(String source) {
    final t = parseMediaTitle(source);
    return t.episode == null ? t.title : '${t.title} ${t.episode}';
  }

  void _onState(PlaybackState s) {
    // Ticks only while playing: an idle app does no work (task 8.1).
    if (s.isPlaying && _timer == null) {
      _timer = Timer.periodic(saveInterval, (_) {
        if (_last.isPlaying) {
          unawaited(_save(_last, thumbnail: _thumbnailDue()));
        }
      });
    } else if (!s.isPlaying) {
      _timer?.cancel();
      _timer = null;
    }
    final previous = _last;
    _last = s;
    if (previous.source != null && previous.source != s.source) {
      unawaited(_save(previous));
      _thumbnail = null;
      _lastThumbnail = null;
    }
    final source = s.source;
    if (source != null && s.isLoaded && _recordedSource != source) {
      _recordedSource = source;
      unawaited(_save(s));
    }
    if (source == null) _recordedSource = null;
    if (s.isCompleted && !previous.isCompleted && source == previous.source) {
      unawaited(_save(s, finished: true));
    } else if (previous.isPlaying && !s.isPlaying && !s.isCompleted) {
      unawaited(_save(s, thumbnail: true));
    }
  }

  bool _thumbnailDue() {
    if (_last.position < firstThumbnailAfter) return false;
    final last = _lastThumbnail;
    return last == null || clock.now().difference(last) >= thumbnailInterval;
  }

  Future<void> _save(
    PlaybackState s, {
    bool thumbnail = false,
    bool finished = false,
  }) async {
    final source = s.source;
    if (source == null || !s.isLoaded) return;
    if (thumbnail && s.videoWidth != null && source == _last.source) {
      _thumbnail = await _takeThumbnail(source) ?? _thumbnail;
    }
    await _repo.record(
      source: source,
      title: titleFor(source),
      position: finished ? s.duration : s.position,
      duration: s.duration,
      thumbnailPath: _thumbnail,
      finished: finished ? true : null,
    );
  }

  Future<String?> _takeThumbnail(String source) async {
    try {
      final dir = Directory(
        p.join(ref.read(appCacheDirProvider).path, 'thumbnails'),
      );
      await dir.create(recursive: true);
      final key = fnv1a64(source);
      // A new name each time so image caches don't show a stale frame.
      final path = p.join(
        dir.path,
        '$key-${clock.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.read(playerServiceProvider).screenshotTo(path);
      for (final f in dir.listSync().whereType<File>()) {
        if (p.basename(f.path).startsWith(key) && f.path != path) {
          f.deleteSync();
        }
      }
      _lastThumbnail = clock.now();
      return path;
    } on Object {
      return null;
    }
  }

  /// Saves now (app exit).
  Future<void> saveNow() => _save(_last);
}

final historyControllerProvider = NotifierProvider<HistoryController, void>(
  HistoryController.new,
);
