import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';

/// The queue item about to play and how long until it does.
@immutable
class UpNext {
  const new({
    required this.index,
    required this.source,
    required this.secondsLeft,
  });

  final int index;
  final String source;
  final int secondsLeft;
}

/// "Up next in 10 s" between queue items (own suggestion): gives a moment
/// to stay on the credits or stop, instead of jumping straight on.
/// Started by the queue when a file ends and Settings › Playback › Up next
/// countdown is above 0.
class UpNextController extends Notifier<UpNext?> {
  Timer? _timer;

  @override
  UpNext? build() {
    // The queue cancels the countdown itself when it plays something else
    // (a listen here would make the two providers depend on each other).
    ref
      ..onDispose(() => _timer?.cancel())
      ..listen(
        playbackStateProvider.select((s) => s.value?.isCompleted ?? false),
        (was, now) {
          // Seeking back into the finished file means "stay here".
          if ((was ?? false) && !now) cancel();
        },
      );
    return null;
  }

  void start({
    required int index,
    required String source,
    required int seconds,
  }) {
    _timer?.cancel();
    state = UpNext(index: index, source: source, secondsLeft: seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s == null) return;
      if (s.secondsLeft <= 1) {
        unawaited(playNow());
      } else {
        state = UpNext(
          index: s.index,
          source: s.source,
          secondsLeft: s.secondsLeft - 1,
        );
      }
    });
  }

  Future<void> playNow() async {
    final s = state;
    cancel();
    if (s != null) await ref.read(playlistProvider.notifier).playAt(s.index);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}

final upNextProvider = NotifierProvider<UpNextController, UpNext?>(
  UpNextController.new,
);
