import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kyndrel/core/platform/window_service.dart';

/// [WindowService] on Android (task 6.1). There is one full-screen window:
/// "full screen" hides the system bars (immersive mode); moving, resizing
/// and maximising do nothing. Lifecycle callbacks follow the activity:
/// [onHidden] when it goes to the background, [onClose] when it is
/// destroyed (back out of the app).
class MobileWindowService implements WindowService {
  new() {
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_run(_hidden)),
      onShow: () => unawaited(_run(_shown)),
      onDetach: () => unawaited(_run(_close)),
    );
  }

  late final AppLifecycleListener _lifecycle;
  final _close = <Future<void> Function()>[];
  final _hidden = <Future<void> Function()>[];
  final _shown = <Future<void> Function()>[];
  bool _isFullScreen = false;
  final _fullScreenChanges = StreamController<bool>.broadcast();

  static Future<void> _run(List<Future<void> Function()> callbacks) async {
    for (final callback in List.of(callbacks)) {
      try {
        await callback().timeout(const Duration(seconds: 2));
      } on Object {
        // Never block the lifecycle on a failed save.
      }
    }
  }

  @override
  bool get isMaximized => true;

  @override
  Stream<bool> get maximized => Stream.value(true);

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  /// Saves (close callbacks), then leaves the app.
  @override
  Future<void> close() async {
    await _run(_close);
    await SystemNavigator.pop();
  }

  @override
  Future<void> startDragging() async {}

  @override
  bool get isFullScreen => _isFullScreen;

  @override
  Stream<bool> get fullScreen => Stream.multi((listener) {
    listener.add(_isFullScreen);
    final sub = _fullScreenChanges.stream.listen(listener.addSync);
    listener.onCancel = sub.cancel;
  });

  @override
  Future<void> setFullScreen({required bool fullScreen}) async {
    await SystemChrome.setEnabledSystemUIMode(
      fullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (fullScreen == _isFullScreen) return;
    _isFullScreen = fullScreen;
    _fullScreenChanges.add(fullScreen);
  }

  @override
  void onClose(Future<void> Function() callback) => _close.add(callback);

  @override
  void onHidden(Future<void> Function() callback) => _hidden.add(callback);

  @override
  void onShown(Future<void> Function() callback) => _shown.add(callback);

  // Picture-in-picture uses Android's own PiP (task 6.6), not window bounds.
  @override
  Future<Rect> getBounds() => workArea();

  @override
  Future<void> setBounds(Rect bounds) async {}

  @override
  Future<void> setAlwaysOnTop({required bool onTop}) async {}

  @override
  Future<void> setAspectRatio(double ratio) async {}

  @override
  Future<void> setMinimumSize(Size size) async {}

  @override
  Future<Rect> workArea() async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return Offset.zero & (view.physicalSize / view.devicePixelRatio);
  }

  void dispose() {
    _lifecycle.dispose();
    unawaited(_fullScreenChanges.close());
  }
}
