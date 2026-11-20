import 'package:kyndrel/core/platform/device_media.dart';

class FakeDeviceMedia implements DeviceMedia {
  List<DeviceFile> picks = const [];

  /// What the "any file" picker returns (a local copy's path).
  String? pickedCopy;

  @override
  Future<List<DeviceFile>> pick({bool multiple = false}) async => picks;

  @override
  Future<String?> pickFileCopy() async => pickedCopy;
}
