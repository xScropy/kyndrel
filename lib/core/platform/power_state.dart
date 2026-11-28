import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';

/// Whether the device runs on external power (task 8.4): background work
/// such as library previews can wait for it.
abstract interface class PowerState {
  /// Plugged in (charging, full, or held at a charge limit). A computer
  /// without a battery counts as plugged in.
  Future<bool> onExternalPower();

  /// The system's battery saver is on.
  Future<bool> batterySaver();
}

/// [PowerState] through battery_plus (Android, iOS, macOS, Windows, Linux
/// via UPower).
class BatteryPowerState implements PowerState {
  new({required this.mobile, Battery? battery})
    : _battery = battery ?? Battery();

  /// Phones always have a battery: an unknown state is not "plugged in".
  final bool mobile;
  final Battery _battery;

  @override
  Future<bool> onExternalPower() async {
    try {
      return switch (await _battery.batteryState) {
        BatteryState.charging ||
        BatteryState.full ||
        BatteryState.connectedNotCharging => true,
        BatteryState.discharging => false,
        BatteryState.unknown => !mobile,
      };
    } on Object {
      return !mobile;
    }
  }

  @override
  Future<bool> batterySaver() async {
    try {
      return await _battery.isInBatterySaveMode;
    } on Object {
      return false;
    }
  }
}

final powerStateProvider = Provider<PowerState>(
  (ref) => BatteryPowerState(
    mobile: ref.watch(platformCapabilitiesProvider).isMobile,
  ),
);
