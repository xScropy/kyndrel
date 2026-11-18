import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Whether the playback controls are showing (task 1.8).
///
/// Controls hide [hideDelay] after the last [show] while playback is running,
/// unless something holds a lock (an open popover or panel) or playback is
/// paused.
class ControlsVisibility extends Notifier<bool> {
  static const hideDelay = Duration(seconds: 3);

  /// From Settings › Appearance, or [hideDelay] without settings (tests).
  Duration get _delay {
    try {
      return Duration(seconds: ref.read(settingsProvider).controlsHideSeconds);
    } on Object {
      return hideDelay;
    }
  }

  Timer? _timer;
  final _locks = <Object>{};
  bool _autoHide = false;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return true;
  }

  /// Shows the controls and restarts the hide timer (mouse move, key press).
  void show() {
    state = true;
    _restart();
  }

  /// Hides immediately (touch tap on the video), unless locked.
  void hide() {
    if (_locks.isNotEmpty) return;
    _timer?.cancel();
    state = false;
  }

  void toggle() => state ? hide() : show();

  /// Turns auto-hide on while playing and off while paused or idle.
  void setAutoHide({required bool enabled}) {
    _autoHide = enabled;
    if (!enabled) {
      _timer?.cancel();
      state = true;
    } else {
      _restart();
    }
  }

  /// Keeps the controls up until [unlock] is called with the same [owner].
  void lock(Object owner) {
    _locks.add(owner);
    _timer?.cancel();
    state = true;
  }

  void unlock(Object owner) {
    if (_locks.remove(owner)) _restart();
  }

  /// Drops [owner]'s lock without restarting the hide timer or changing
  /// state, so it is safe from `dispose` (the owner is going away).
  void release(Object owner) => _locks.remove(owner);

  @visibleForTesting
  bool get isLocked => _locks.isNotEmpty;

  void _restart() {
    _timer?.cancel();
    if (!_autoHide || _locks.isNotEmpty) return;
    _timer = Timer(_delay, () {
      if (_locks.isEmpty && _autoHide) state = false;
    });
  }
}

final controlsVisibilityProvider = NotifierProvider<ControlsVisibility, bool>(
  ControlsVisibility.new,
);
