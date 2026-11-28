import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';

/// Volume changes from the slider, ↑/↓ and the scroll wheel go through here
/// so they all persist the value and show the first-boost warning.
abstract final class VolumeActions {
  /// Step for ↑/↓ and one scroll notch, in percent.
  static const step = 5.0;

  static const boostWarning =
      'Volume above 100% boosts the signal (up to 500%) and can distort. A '
      'limiter is on '
      'to reduce clipping (Settings › Audio).';

  /// Sets the volume. [persist] is false while a slider is being dragged.
  static Future<void> set(
    WidgetRef ref,
    double volume, {
    bool persist = true,
    bool showOsd = false,
    void Function(String message)? onFirstBoost,
  }) async {
    final settings = ref.read(settingsProvider);
    final max = settings.volumeBoostMax.clamp(100, PlayerService.maxVolume);
    final v = volume.clamp(0, max).toDouble();
    await ref.read(playerServiceProvider).setVolume(v);
    if (showOsd) ref.read(volumeHudProvider.notifier).show();
    if (v > 100 && !settings.boostWarningSeen && onFirstBoost != null) {
      onFirstBoost(boostWarning);
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(boostWarningSeen: true));
    }
    if (persist) {
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(volume: v));
    }
  }

  static Future<void> changeBy(
    WidgetRef ref,
    double delta, {
    void Function(String message)? onFirstBoost,
  }) {
    final current = ref.read(playerServiceProvider).state.volume;
    return set(ref, current + delta, showOsd: true, onFirstBoost: onFirstBoost);
  }

  static Future<void> toggleMute(WidgetRef ref) async {
    final service = ref.read(playerServiceProvider);
    await service.toggleMute();
    ref.read(volumeHudProvider.notifier).show();
  }
}
