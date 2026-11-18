import 'package:kyndrel/core/platform/device_media.dart';

class FakeDeviceMedia implements DeviceMedia {
  new({this.library = const [], this.granted = false, this.grant = true});

  final List<DeviceVideo> library;
  bool granted;

  /// What the permission prompt answers.
  final bool grant;
  List<DeviceFile> picks = const [];

  @override
  Future<List<DeviceFile>> pick({bool multiple = false}) async => picks;

  @override
  Future<bool> requestVideoAccess() async => granted = granted || grant;

  @override
  Future<List<DeviceVideo>> videos() async => granted ? library : const [];
}

DeviceVideo video(String name, String folder, {int id = 1}) => DeviceVideo(
  file: DeviceFile('content://media/external/video/media/$id', name),
  folder: folder,
  duration: const Duration(minutes: 3),
  size: 1000,
  added: DateTime(2026),
);
