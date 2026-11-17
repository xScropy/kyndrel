import 'dart:async';

import 'package:kyndrel/core/platform/window_service.dart';

class FakeWindowService implements WindowService {
  new({bool maximized = false}) : _isMaximized = maximized;

  final calls = <String>[];
  bool _isMaximized;
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  bool get isMaximized => _isMaximized;

  @override
  Stream<bool> get maximized => Stream.multi((listener) {
    listener.add(_isMaximized);
    final sub = _changes.stream.listen(listener.addSync);
    listener.onCancel = sub.cancel;
  });

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async {
    calls.add('toggleMaximize');
    _isMaximized = !_isMaximized;
    _changes.add(_isMaximized);
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  bool _isFullScreen = false;
  final _fullScreenChanges = StreamController<bool>.broadcast(sync: true);
  final closeCallbacks = <Future<void> Function()>[];

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
    calls.add('fullScreen($fullScreen)');
    _isFullScreen = fullScreen;
    _fullScreenChanges.add(fullScreen);
  }

  @override
  void onClose(Future<void> Function() callback) =>
      closeCallbacks.add(callback);
}
