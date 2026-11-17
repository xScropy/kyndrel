import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';

/// Full-screen toggling shared by the button, F, Esc and double-click
/// (task 1.7).
abstract final class FullscreenActions {
  static Future<void> toggle(WidgetRef ref) {
    final window = ref.read(windowServiceProvider);
    return window.setFullScreen(fullScreen: !window.isFullScreen);
  }

  /// Leaves full screen; returns false if the window wasn't full screen.
  static Future<bool> exit(WidgetRef ref) async {
    final window = ref.read(windowServiceProvider);
    if (!window.isFullScreen) return false;
    await window.setFullScreen(fullScreen: false);
    return true;
  }
}
