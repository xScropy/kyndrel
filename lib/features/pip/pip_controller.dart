import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';

/// Picture-in-picture: the same window and player, shrunk to a small,
/// always-on-top, aspect-locked window in the screen's corner (task 4.1).
/// No second player, so playback never restarts.
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
  bool build() => false;

  WindowService get _window => ref.read(windowServiceProvider);

  Future<void> toggle() => state ? exit() : enter();

  Future<void> enter() async {
    if (state) return;
    final window = _window;
    _wasFullScreen = window.isFullScreen;
    if (_wasFullScreen) await window.setFullScreen(fullScreen: false);
    _savedBounds = await window.getBounds();

    final p = ref.read(playerServiceProvider).state;
    final w = p.videoWidth;
    final h = p.videoHeight;
    final aspect = w != null && h != null && w > 0 && h > 0 ? w / h : 16 / 9;
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
    if (!state) return;
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
