import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

@immutable
class ResumeOffer {
  const new({required this.source, required this.position});

  final String source;
  final Duration position;
}

/// Saves the position on pause, every [saveInterval] while playing, when
/// another file is opened and when the app closes; offers to resume when a
/// known file is reopened (task 1.12).
class ResumeController extends Notifier<ResumeOffer?> {
  static const saveInterval = Duration(seconds: 15);

  PlaybackState _last = PlaybackState.initial;
  String? _checkedSource;
  String? _autoResume;
  Timer? _timer;

  ResumeRepository get _repo => ref.read(resumeRepositoryProvider);

  @override
  ResumeOffer? build() {
    final service = ref.watch(playerServiceProvider);
    final sub = service.states.listen(_onState);
    _timer = Timer.periodic(saveInterval, (_) {
      if (_last.isPlaying) unawaited(saveNow());
    });
    ref.onDispose(() {
      unawaited(sub.cancel());
      _timer?.cancel();
    });
    return null;
  }

  void _onState(PlaybackState s) {
    final previous = _last;
    _last = s;

    // Another file (or none) replaced the previous one: save where it was.
    if (previous.source != null && previous.source != s.source) {
      unawaited(_save(previous));
      if (state?.source == previous.source) state = null;
    }

    if (s.isCompleted && previous.source == s.source && !previous.isCompleted) {
      unawaited(_repo.remove(s.source!));
    } else if (previous.isPlaying && !s.isPlaying && !s.isCompleted) {
      unawaited(_save(s));
    }

    final source = s.source;
    if (source != null && s.isLoaded && _checkedSource != source) {
      _checkedSource = source;
      unawaited(_offerFor(source));
    }
    if (source == null) _checkedSource = null;
  }

  Future<void> _offerFor(String source) async {
    final point = await _repo.get(source);
    if (point == null) return;
    final now = _last;
    if (now.source != source) return;
    final duration = now.duration > Duration.zero
        ? now.duration
        : point.duration;
    if (!ResumeRepository.isResumable(point.position, duration)) return;
    // Don't offer if the user already moved well past the start.
    if (now.position > const Duration(seconds: 5)) return;
    if (_autoResume == source) {
      _autoResume = null;
      await ref.read(playerServiceProvider).seek(point.position);
      return;
    }
    state = ResumeOffer(source: source, position: point.position);
  }

  Future<void> _save(PlaybackState s) async {
    final source = s.source;
    if (source == null || !s.isLoaded) return;
    await _repo.save(source, s.position, s.duration);
  }

  /// Saves the current position now (app exit).
  Future<void> saveNow() => _save(_last);

  Future<void> accept() async {
    final offer = state;
    state = null;
    if (offer == null) return;
    await ref.read(playerServiceProvider).seek(offer.position);
  }

  void dismiss() => state = null;

  /// The next load of [source] jumps straight to its saved position instead
  /// of asking (continue watching).
  // ignore: use_setters_to_change_properties, reads better at call sites
  void resumeNextLoadOf(String source) => _autoResume = source;
}

final resumeControllerProvider =
    NotifierProvider<ResumeController, ResumeOffer?>(ResumeController.new);
