import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// The phone's media volume (STREAM_MUSIC), for the volume swipe (6.3).
abstract interface class SystemVolumeService {
  /// 0–1.
  Future<double> current();
  Future<void> set(double value);
}

class MediaStreamVolume implements SystemVolumeService {
  const new();

  @override
  Future<double> current() async =>
      await FlutterVolumeController.getVolume() ?? 1;

  @override
  Future<void> set(double value) async {
    // Kyndrel draws its own level; no system volume panel on top.
    await FlutterVolumeController.updateShowSystemUI(false);
    await FlutterVolumeController.setVolume(value.clamp(0.0, 1.0));
  }
}

/// Null on desktop, where the swipe changes Kyndrel's own volume only.
final systemVolumeProvider = Provider<SystemVolumeService?>(
  (ref) => Platform.isAndroid ? const MediaStreamVolume() : null,
);

/// One 0–200 % scale for the volume swipe (task 6.3): the first 100 % is
/// the phone's media volume (Kyndrel at 100 %), the rest is Kyndrel's
/// boost with the phone at its maximum.
abstract final class CombinedVolume {
  static const double max = 200;

  /// Where the scale is now, from the phone volume (0–1) and Kyndrel's.
  static double of({required double system, required double player}) =>
      player > 100 ? player : system * player;

  /// The phone volume (0–1) and Kyndrel's volume for [combined].
  static ({double system, double player}) split(double combined) {
    final c = combined.clamp(0.0, max);
    return c <= 100
        ? (system: c / 100, player: 100.0)
        : (system: 1.0, player: c);
  }
}
