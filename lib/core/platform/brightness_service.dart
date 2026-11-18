import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Screen brightness for the brightness swipe (task 6.3). Only Kyndrel's
/// window changes; the system setting is untouched and comes back when
/// the app is left.
abstract interface class BrightnessService {
  /// 0–1.
  Future<double> current();
  Future<void> set(double value);

  /// Back to the system brightness.
  Future<void> reset();
}

class WindowBrightnessService implements BrightnessService {
  const new();

  @override
  Future<double> current() => ScreenBrightness.instance.application;

  @override
  Future<void> set(double value) => ScreenBrightness.instance
      .setApplicationScreenBrightness(value.clamp(0.0, 1.0));

  @override
  Future<void> reset() =>
      ScreenBrightness.instance.resetApplicationScreenBrightness();
}

/// Null on desktop: there the plugin would change the monitor's own
/// brightness, which is not what a player gesture should do.
final brightnessServiceProvider = Provider<BrightnessService?>(
  (ref) => Platform.isAndroid ? const WindowBrightnessService() : null,
);
