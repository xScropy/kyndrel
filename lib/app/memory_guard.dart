import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps Kyndrel's memory small (task 8.1).
///
/// - Flutter's decoded-image cache is capped well under its 100 MB default:
///   library thumbnails are decoded at their cell size, so this holds a few
///   screens of them.
/// - When the system is short on memory (Android `onTrimMemory`, iOS
///   warnings), Flutter clears that cache itself; this also closes the
///   hidden frame engine and drops decoded storyboard sheets.
/// - A hidden window closes the frame engine too: nobody is scrubbing.
final memoryGuardProvider = Provider<void>((ref) {
  PaintingBinding.instance.imageCache
    ..maximumSize = imageCacheEntries
    ..maximumSizeBytes = imageCacheBytes;
  void release() {
    unawaited(ref.read(frameEngineProvider).releaseIdle());
    ref.read(frameImageCacheProvider).clear();
  }
  final observer = _PressureObserver(release);
  WidgetsBinding.instance.addObserver(observer);
  ref.read(windowServiceProvider).onHidden(() async => release());
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

/// Most decoded images kept in memory.
const imageCacheEntries = 300;

/// Most bytes of decoded images kept in memory.
const int imageCacheBytes = 40 * 1024 * 1024;

class _PressureObserver with WidgetsBindingObserver {
  new(this.onPressure);
  final VoidCallback onPressure;

  @override
  void didHaveMemoryPressure() => onPressure();
}
