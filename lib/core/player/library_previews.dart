import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/power_state.dart';
import 'package:kyndrel/core/player/android_frame_source.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Makes library storyboards; its own source so library work never cancels
/// the playing file's storyboard, and at the engine's lowest priority.
final libraryStoryboardSourceProvider = Provider<StoryboardSource>((ref) {
  if (Platform.isAndroid) return AndroidStoryboardSource();
  final s = MpvStoryboardSource(
    engine: ref.watch(frameEngineProvider),
    job: FrameJob.probe,
  );
  ref.onDispose(s.dispose);
  return s;
});

/// Progress of the library previews.
@immutable
class LibraryPreviewsStatus {
  const new({this.running = false, this.made = 0, this.waiting = 0});

  /// Making one now.
  final bool running;

  /// Made this session.
  final int made;

  /// Videos still without one.
  final int waiting;
}

/// Gives library videos their coarse storyboard (one small sheet, the whole
/// video) in advance, like YouTube's storyboards that arrive with the page
/// (task 8.4). Opening a video then scrubs at once, and library cards can
/// flip through scenes on hover.
///
/// Runs only while nothing plays, after [startDelay] of quiet, one video at
/// a time at the frame engine's lowest priority; on phones (or by setting)
/// only while plugged in and never in battery saver.
class LibraryPreviewsController extends Notifier<LibraryPreviewsStatus> {
  /// Quiet time before work starts or resumes.
  static const startDelay = Duration(seconds: 10);

  /// How often a wait for power checks again.
  static const powerRecheck = Duration(minutes: 1);

  final _failed = <String>{};
  bool _running = false;
  bool _disposed = false;
  Timer? _kick;
  Completer<void>? _wake;

  @override
  LibraryPreviewsStatus build() {
    final service = ref.watch(playerServiceProvider);
    final sub = service.states.listen((s) {
      if (s.isPlaying) {
        // Playback has the machine: stop the library work at once.
        unawaited(ref.read(libraryStoryboardSourceProvider).cancel());
      }
      _poke();
    });
    ref
      ..listen(settingsProvider.select((s) => s.libraryPreviews), (_, _) {
        _poke();
      })
      ..onDispose(() {
        _disposed = true;
        _kick?.cancel();
        _wake?.complete();
        unawaited(sub.cancel());
      });
    _poke();
    return const LibraryPreviewsStatus();
  }

  /// Something changed: (re)start after [startDelay] of quiet.
  void _poke() {
    _wake?.complete();
    _wake = null;
    _kick?.cancel();
    _kick = Timer(startDelay, () => unawaited(_run()));
  }

  Future<bool> _allowed() async {
    final mode = ref.read(settingsProvider).libraryPreviews;
    if (mode == LibraryPreviews.off) return false;
    if (ref.read(playerServiceProvider).state.isPlaying) return false;
    final mobile = ref.read(platformCapabilitiesProvider).isMobile;
    final needPower =
        mode == LibraryPreviews.charging ||
        (mode == LibraryPreviews.auto && mobile);
    final power = ref.read(powerStateProvider);
    if (await power.batterySaver()) return false;
    if (needPower && !await power.onExternalPower()) return false;
    return true;
  }

  Future<void> _run() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed) {
        if (!await _allowed()) {
          // Settings and playback poke; power has no event: look again.
          _wake = Completer<void>();
          _kick?.cancel();
          _kick = Timer(powerRecheck, _poke);
          return;
        }
        final next = await _next();
        state = LibraryPreviewsStatus(
          running: next != null,
          made: state.made,
          waiting: next == null ? 0 : state.waiting,
        );
        if (next == null) return;
        final board = next.$1;
        final ok = await ref
            .read(libraryStoryboardSourceProvider)
            .render(board, maxLevel: 0);
        if (_disposed) return;
        if (ok) {
          state = LibraryPreviewsStatus(
            running: true,
            made: state.made + 1,
            waiting: state.waiting,
          );
        } else if (!ref.read(playerServiceProvider).state.isPlaying) {
          // Not stopped by playback: this file can't be read. Skip it.
          _failed.add(board.source);
        }
      }
    } finally {
      _running = false;
    }
  }

  /// The newest library video without a coarse storyboard.
  Future<(Storyboard, LibraryItem)?> _next() async {
    final db = ref.read(databaseProvider);
    final items =
        await (db.select(db.libraryItems)
              ..where(
                (t) =>
                    t.kind.equals(MediaKind.video.name) &
                    t.probed.equals(true) &
                    t.durationMs.isBiggerThanValue(0),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.added)]))
            .get();
    final cache = ref.read(appCacheDirProvider);
    var waiting = 0;
    (Storyboard, LibraryItem)? first;
    for (final item in items) {
      if (_failed.contains(item.uri)) continue;
      final board = Storyboard.read(
        cache,
        item.uri,
        Duration(milliseconds: item.durationMs!),
      );
      if (board.levels.first.complete) continue;
      waiting++;
      first ??= (board, item);
    }
    state = LibraryPreviewsStatus(
      running: state.running,
      made: state.made,
      waiting: waiting,
    );
    return first;
  }
}

final libraryPreviewsProvider =
    NotifierProvider<LibraryPreviewsController, LibraryPreviewsStatus>(
      LibraryPreviewsController.new,
    );
