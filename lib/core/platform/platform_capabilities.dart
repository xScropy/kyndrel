import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this device can do (task 6.1). Features ask this instead of
/// checking `Platform`, and tests override it to try the phone UI.
@immutable
class PlatformCapabilities {
  const new({
    required this.isDesktop,
    required this.hasWindowControls,
    required this.canRunExecutables,
  });

  /// The device running the app.
  factory current() {
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return PlatformCapabilities(
      isDesktop: desktop,
      hasWindowControls: desktop,
      canRunExecutables: desktop,
    );
  }

  static const desktop = PlatformCapabilities(
    isDesktop: true,
    hasWindowControls: true,
    canRunExecutables: true,
  );

  static const phone = PlatformCapabilities(
    isDesktop: false,
    hasWindowControls: false,
    canRunExecutables: false,
  );

  final bool isDesktop;

  /// Minimise/maximise/close buttons and a draggable title bar.
  final bool hasWindowControls;

  /// Helper programs such as `ffmpeg` and `yt-dlp` can be started (not on
  /// Android, where apps can't run executables from the user's PATH).
  final bool canRunExecutables;

  bool get isMobile => !isDesktop;
}

final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => PlatformCapabilities.current(),
);
