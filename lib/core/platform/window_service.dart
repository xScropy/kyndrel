import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Native window actions used by the custom title bar (task 1.2).
abstract interface class WindowService {
  bool get isMaximized;

  /// Maximized state, starting with the current value.
  Stream<bool> get maximized;

  Future<void> minimize();

  /// Maximizes, or restores if already maximized.
  Future<void> toggleMaximize();

  Future<void> close();

  /// Starts a native window move; call from a drag start.
  Future<void> startDragging();

  bool get isFullScreen;

  /// Full-screen state, starting with the current value.
  Stream<bool> get fullScreen;

  Future<void> setFullScreen({required bool fullScreen});

  /// Called before the window closes (e.g. to save the resume position).
  /// The window closes once [callback] completes.
  void onClose(Future<void> Function() callback);

  // Picture-in-picture (task 4.1).
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<void> setAlwaysOnTop({required bool onTop});

  /// Locks resizing to [ratio] (width / height); 0 unlocks.
  Future<void> setAspectRatio(double ratio);
  Future<void> setMinimumSize(Size size);

  /// The usable area of the primary display (without task bars).
  Future<Rect> workArea();
}

/// [WindowService] on the `window_manager` plugin.
class WindowManagerService with WindowListener implements WindowService {
  new _(this._isMaximized, this._isFullScreen);

  /// Reads the initial state and starts listening to window events.
  /// Call after `windowManager.ensureInitialized()`.
  static Future<WindowManagerService> create() async {
    final service = WindowManagerService._(
      await windowManager.isMaximized(),
      await windowManager.isFullScreen(),
    );
    windowManager.addListener(service);
    // Let onWindowClose run the close callbacks first.
    await windowManager.setPreventClose(true);
    return service;
  }

  bool _isMaximized;
  bool _isFullScreen;
  final _changes = StreamController<bool>.broadcast();
  final _fullScreenChanges = StreamController<bool>.broadcast();
  final _closeCallbacks = <Future<void> Function()>[];

  @override
  bool get isMaximized => _isMaximized;

  @override
  Stream<bool> get maximized => Stream.multi((listener) {
    listener.add(_isMaximized);
    final sub = _changes.stream.listen(listener.addSync);
    listener.onCancel = sub.cancel;
  });

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

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
    await windowManager.setFullScreen(fullScreen);
    _setFullScreen(fullScreen);
  }

  @override
  void onClose(Future<void> Function() callback) =>
      _closeCallbacks.add(callback);

  @override
  Future<void> onWindowClose() async {
    for (final callback in _closeCallbacks) {
      try {
        await callback().timeout(const Duration(seconds: 2));
      } on Object {
        // Never block closing on a failed save.
      }
    }
    await windowManager.destroy();
  }

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<void> setAlwaysOnTop({required bool onTop}) =>
      windowManager.setAlwaysOnTop(onTop);

  @override
  Future<void> setAspectRatio(double ratio) =>
      windowManager.setAspectRatio(ratio);

  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  @override
  Future<Rect> workArea() async {
    final d = await screenRetriever.getPrimaryDisplay();
    final pos = d.visiblePosition ?? Offset.zero;
    final size = d.visibleSize ?? d.size;
    return pos & size;
  }

  @override
  void onWindowEnterFullScreen() => _setFullScreen(true);

  @override
  void onWindowLeaveFullScreen() => _setFullScreen(false);

  void _setFullScreen(bool value) {
    if (value == _isFullScreen) return;
    _isFullScreen = value;
    _fullScreenChanges.add(value);
  }

  @override
  void onWindowMaximize() => _set(maximized: true);

  @override
  void onWindowUnmaximize() => _set(maximized: false);

  @override
  void onWindowRestore() => unawaited(_resync());

  @override
  void onWindowResized() => unawaited(_resync());

  /// Some platforms (notably Linux) don't always send maximize events, so
  /// re-read the state after restores and resizes.
  Future<void> _resync() async =>
      _set(maximized: await windowManager.isMaximized());

  void _set({required bool maximized}) {
    if (maximized == _isMaximized) return;
    _isMaximized = maximized;
    _changes.add(maximized);
  }
}

/// Overridden in `main.dart` with an initialised [WindowManagerService], and
/// in tests with a fake.
final windowServiceProvider = Provider<WindowService>(
  (ref) => throw UnimplementedError('windowServiceProvider not overridden'),
);

final isMaximizedProvider = StreamProvider<bool>(
  (ref) => ref.watch(windowServiceProvider).maximized,
);

final isFullScreenProvider = StreamProvider<bool>(
  (ref) => ref.watch(windowServiceProvider).fullScreen,
);
