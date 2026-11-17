import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';

/// A sleep timer choice (task 2.3).
@immutable
sealed class SleepOption {
  const new();

  String get label;

  static const all = <SleepOption>[
    SleepAfter(Duration(minutes: 15)),
    SleepAfter(Duration(minutes: 30)),
    SleepAfter(Duration(minutes: 45)),
    SleepAfter(Duration(hours: 1)),
    SleepAfter(Duration(hours: 2)),
    SleepAfter(Duration(hours: 3)),
    SleepAfter(Duration(hours: 4)),
    SleepAfter(Duration(hours: 6)),
    SleepAtEndOfEpisode(),
    SleepAtEndOfEpisode(extraEpisodes: 1),
  ];
}

/// Pause after a fixed time.
class SleepAfter extends SleepOption {
  const new(this.duration);
  final Duration duration;

  @override
  String get label => duration.inMinutes < 60
      ? '${duration.inMinutes} min'
      : duration.inHours == 1
      ? '1 hour'
      : '${duration.inHours} hours';

  @override
  bool operator ==(Object other) =>
      other is SleepAfter && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

/// Pause when the current episode ends, or after [extraEpisodes] more.
class SleepAtEndOfEpisode extends SleepOption {
  const new({this.extraEpisodes = 0});
  final int extraEpisodes;

  @override
  String get label =>
      extraEpisodes == 0 ? 'End of episode' : 'End of next episode';

  @override
  bool operator ==(Object other) =>
      other is SleepAtEndOfEpisode && other.extraEpisodes == extraEpisodes;

  @override
  int get hashCode => extraEpisodes.hashCode;
}

@immutable
class SleepTimerState {
  const new({
    required this.option,
    this.remaining,
    this.episodesLeft = 0,
    this.fading = false,
  });

  final SleepOption option;

  /// Time until playback pauses, when known. For episode modes this is the
  /// time left in the episode that ends the timer, at the current speed.
  final Duration? remaining;

  /// Episodes still to finish before the final one (episode modes).
  final int episodesLeft;
  final bool fading;
}

/// Runs the sleep timer: counts down, fades the volume out over the last
/// [fadeDuration], then pauses and restores the volume.
class SleepTimer extends Notifier<SleepTimerState?> {
  static const fadeDuration = Duration(seconds: 30);
  static const tick = Duration(seconds: 1);

  Timer? _ticker;
  DateTime? _endsAt;
  double? _volumeBeforeFade;
  StreamSubscription<String>? _completions;

  PlayerService get _player => ref.read(playerServiceProvider);

  @override
  SleepTimerState? build() {
    ref.onDispose(_stop);
    return null;
  }

  /// Starts [option]; choosing the active option again cancels the timer,
  /// choosing another one replaces it.
  Future<void> select(SleepOption option) async {
    final current = state;
    await cancel();
    if (current?.option == option) return;

    switch (option) {
      case SleepAfter(:final duration):
        _endsAt = clock.now().add(duration);
        state = SleepTimerState(option: option, remaining: duration);
      case SleepAtEndOfEpisode(:final extraEpisodes):
        state = SleepTimerState(option: option, episodesLeft: extraEpisodes);
        _completions = _player.completions.listen((_) => _onEpisodeEnd());
    }
    _ticker = Timer.periodic(tick, (_) => unawaited(_onTick()));
    await _onTick();
  }

  Future<void> cancel() async {
    _stop();
    await _restoreVolume();
    state = null;
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_completions?.cancel());
    _completions = null;
    _endsAt = null;
  }

  Future<void> _onTick() async {
    final s = state;
    if (s == null) return;
    final remaining = switch (s.option) {
      SleepAfter() => _endsAt!.difference(clock.now()),
      SleepAtEndOfEpisode() => _episodeRemaining(s),
    };
    if (remaining == null) {
      state = SleepTimerState(option: s.option, episodesLeft: s.episodesLeft);
      return;
    }
    if (remaining <= Duration.zero) {
      if (s.option is SleepAfter) await _fire();
      return;
    }
    final fading = remaining <= fadeDuration;
    if (fading) await _fade(remaining);
    state = SleepTimerState(
      option: s.option,
      remaining: remaining,
      episodesLeft: s.episodesLeft,
      fading: fading,
    );
  }

  /// Time left in the episode that ends the timer, or null while that isn't
  /// the current one (or its length is unknown).
  Duration? _episodeRemaining(SleepTimerState s) {
    if (s.episodesLeft > 0) return null;
    final p = _player.state;
    if (p.duration <= Duration.zero || p.isCompleted) return null;
    final left = p.duration - p.position;
    return left * (1 / (p.rate <= 0 ? 1 : p.rate));
  }

  Future<void> _fade(Duration remaining) async {
    final original = _volumeBeforeFade ??= _player.state.volume;
    final fraction = remaining.inMilliseconds / fadeDuration.inMilliseconds;
    await _player.setVolume(original * fraction.clamp(0.0, 1.0));
  }

  void _onEpisodeEnd() {
    final s = state;
    if (s == null) return;
    if (s.episodesLeft > 0) {
      // A finished file resets any fade from the ending of that episode.
      unawaited(_restoreVolume());
      state = SleepTimerState(
        option: s.option,
        episodesLeft: s.episodesLeft - 1,
      );
      return;
    }
    unawaited(_fire());
  }

  Future<void> _fire() async {
    _stop();
    await _player.pause();
    await _restoreVolume();
    state = null;
  }

  Future<void> _restoreVolume() async {
    final v = _volumeBeforeFade;
    _volumeBeforeFade = null;
    if (v != null) await _player.setVolume(v);
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimer, SleepTimerState?>(
  SleepTimer.new,
);
