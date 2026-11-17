import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Applies saved settings to the engine at start-up and whenever they
/// change: volume, limiter, subtitle auto-load and subtitle style.
final engineSyncProvider = Provider<void>((ref) {
  final service = ref.watch(playerServiceProvider);
  final initial = ref.read(settingsProvider);
  unawaited(() async {
    await service.setLimiterEnabled(enabled: initial.limiterEnabled);
    await service.setVolume(initial.volume);
    await service.setAutoLoadSubtitles(enabled: initial.autoLoadSubtitles);
    await service.applySubtitleStyle(initial.subtitleStyle);
  }());

  ref
    ..listen(settingsProvider.select((s) => s.limiterEnabled), (_, v) {
      unawaited(service.setLimiterEnabled(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.autoLoadSubtitles), (_, v) {
      unawaited(service.setAutoLoadSubtitles(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.subtitleStyle), (_, v) {
      unawaited(service.applySubtitleStyle(v));
    });
});
