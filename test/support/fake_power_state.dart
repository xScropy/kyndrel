import 'package:kyndrel/core/platform/power_state.dart';

/// Plugged in, no battery saver, unless a test says otherwise.
class FakePowerState implements PowerState {
  bool pluggedIn = true;
  bool saver = false;

  @override
  Future<bool> onExternalPower() async => pluggedIn;

  @override
  Future<bool> batterySaver() async => saver;
}
