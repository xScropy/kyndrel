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
}
