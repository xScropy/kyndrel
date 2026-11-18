import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/native_pip.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Picture-in-picture: the same window and player, shrunk to a small,
/// always-on-top, aspect-locked window in the screen's corner (task 4.1).
/// No second player, so playback never restarts.
///
/// On Android it is the system's PiP instead (task 6.6): the state follows
/// what Android reports, and going Home while a video plays enters it
/// when the "Picture-in-picture on Home" setting is on.
class PipController extends Notifier<bool> {
  /// Width of the PiP window when it opens.
  static const width = 400.0;

  /// Distance from the screen edges.
  static const margin = 24.0;

  /// Normal minimum size (matches main.dart).
  static const normalMinimum = Size(720, 405);

  Rect? _savedBounds;
  bool _wasFullScreen = false;

  @override
  bool build() {
    final native = ref.watch(nativePipProvider);
    if (native != null) _watchNative(native);
    return false;
  }

  void _watchNative(NativePip native) {
    final changes = native.changes.listen((inPip) => state = inPip);
    final service = ref.read(playerServiceProvider);
    ({bool auto, double aspect, bool playing})? last;
    void push() {
      final p = service.state;
      final next = (
        auto: ref.read(settingsProvider).autoPip && p.isPlaying,
        aspect: _aspectOf(p.videoWidth, p.videoHeight),
        playing: p.isPlaying,
      );
      if (next == last) return;
      last = next;
      unawaited(
        native.configure(
          auto: next.auto,
          aspect: next.aspect,
          playing: next.playing,
        ),
      );
    }

    final states = service.states.listen((_) => push());
    final settings = ref.listen(
      settingsProvider.select((s) => s.autoPip),
      (_, _) => push(),
    );
    ref.onDispose(() {
      unawaited(changes.cancel());
      unawaited(states.cancel());
      settings.close();
    });
  }

  static double _aspectOf(int? w, int? h) =>
      w != null && h != null && w > 0 && h > 0 ? w / h : 16 / 9;

  WindowService get _window => ref.read(windowServiceProvider);

  Future<void> toggle() => state ? exit() : enter();

  Future<void> enter() async {
    if (state) return;
    final native = ref.read(nativePipProvider);
    if (native != null) {
      final p = ref.read(playerServiceProvider).state;
      await native.enter(aspect: _aspectOf(p.videoWidth, p.videoHeight));
      return;
    }
    final window = _window;
    _wasFullScreen = window.isFullScreen;
    if (_wasFullScreen) await window.setFullScreen(fullScreen: false);
    _savedBounds = await window.getBounds();

    final p = ref.read(playerServiceProvider).state;
    final aspect = _aspectOf(p.videoWidth, p.videoHeight);
    final size = Size(width, (width / aspect).roundToDouble());
    final area = await window.workArea();

    await window.setMinimumSize(Size(200, (200 / aspect).roundToDouble()));
    await window.setAspectRatio(aspect);
    await window.setBounds(
      Rect.fromLTWH(
        area.right - size.width - margin,
        area.bottom - size.height - margin,
        size.width,
        size.height,
      ),
    );
    await window.setAlwaysOnTop(onTop: true);
    state = true;
  }

  Future<void> exit() async {
    // System PiP is left with its own expand button.
    if (!state || ref.read(nativePipProvider) != null) return;
    final window = _window;
    await window.setAlwaysOnTop(onTop: false);
    await window.setAspectRatio(0);
    await window.setMinimumSize(normalMinimum);
    final saved = _savedBounds;
    if (saved != null) await window.setBounds(saved);
    if (_wasFullScreen) await window.setFullScreen(fullScreen: true);
    state = false;
  }
}

final pipProvider = NotifierProvider<PipController, bool>(PipController.new);
