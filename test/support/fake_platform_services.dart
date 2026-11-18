import 'package:kyndrel/core/platform/brightness_service.dart';
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
