import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/replay_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Notes what gets watched again (task 8.10): when playback jumps back
/// between [minJump] and [maxJump], the part between the new position and
/// the old one counts as replayed. Nothing leaves the device; incognito
/// records nothing.
class ReplayRecorder extends Notifier<void> {
  static const minJump = Duration(seconds: 3);
  static const maxJump = Duration(minutes: 10);

  PlaybackState _last = PlaybackState.initial;

  @override
  void build() {
    final sub = ref.watch(playerServiceProvider).states.listen(_onState);
    ref.onDispose(() => unawaited(sub.cancel()));
  }

  void _onState(PlaybackState s) {
    final previous = _last;
    _last = s;
    final source = s.source;
    if (source == null ||
        source != previous.source ||
        !s.isLoaded ||
        s.duration <= Duration.zero) {
      return;
    }
    final back = previous.position - s.position;
    if (back < minJump || back > maxJump) return;
    if (ref.read(settingsProvider).incognito) return;
    final d = s.duration.inMilliseconds;
    unawaited(
      ref
          .read(replayRepositoryProvider)
          .addRange(
            source,
            s.position.inMilliseconds / d,
            previous.position.inMilliseconds / d,
          ),
    );
  }
}

final replayRecorderProvider = NotifierProvider<ReplayRecorder, void>(
  ReplayRecorder.new,
);
