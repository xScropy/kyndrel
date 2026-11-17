import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

/// [WindowService] on the `window_manager` plugin.
class WindowManagerService with WindowListener implements WindowService {
  new _(this._isMaximized);

  /// Reads the initial state and starts listening to window events.
  /// Call after `windowManager.ensureInitialized()`.
  static Future<WindowManagerService> create() async {
    final service = WindowManagerService._(await windowManager.isMaximized());
    windowManager.addListener(service);
    return service;
  }

  bool _isMaximized;
  final _changes = StreamController<bool>.broadcast();

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
