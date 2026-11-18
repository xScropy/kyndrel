import 'dart:async';

import 'package:kyndrel/core/platform/brightness_service.dart';
import 'package:kyndrel/core/platform/native_pip.dart';
import 'package:kyndrel/core/platform/system_volume.dart';

class FakeBrightness implements BrightnessService {
  new([this.value = 0.5]);
  double value;
  bool wasReset = false;

  @override
  Future<double> current() async => value;

  @override
  Future<void> set(double v) async => value = v;

  @override
  Future<void> reset() async => wasReset = true;
}

class FakeSystemVolume implements SystemVolumeService {
  new([this.value = 0.5]);
  double value;

  @override
  Future<double> current() async => value;

  @override
  Future<void> set(double v) async => value = v;
}

class FakeNativePip implements NativePip {
  final entered = <double>[];
  final configured = <({bool auto, double aspect, bool playing})>[];
  final _changes = StreamController<bool>.broadcast();

  /// What Android would report.
  void report({required bool inPip}) => _changes.add(inPip);

  @override
  Future<bool> get supported async => true;

  @override
  Future<bool> enter({required double aspect}) async {
    entered.add(aspect);
    return true;
  }

  @override
  Future<void> configure({
    required bool auto,
    required double aspect,
    required bool playing,
  }) async => configured.add((auto: auto, aspect: aspect, playing: playing));

  @override
  Stream<bool> get changes => _changes.stream;
}
