import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';

/// Renders preview frames in the background after a file loads (task
/// 6.4): every chapter start and 19 evenly spaced points, so the first
/// drag on a phone already shows pictures. One frame at a time; stops when
/// another file opens.
final previewPrewarmProvider = Provider<void>((ref) {
  String? warmed;
  var generation = 0;
  // A direct subscription: a provider that is only read once has its
  // ref.listen subscriptions paused by Riverpod.
  final sub = ref.watch(playerServiceProvider).states.listen((s) {
    final source = s.source;
    if (source == null || !s.isLoaded) return;
    if (s.duration <= Duration.zero || source == warmed) return;
    warmed = source;
    final run = ++generation;
    final duration = s.duration;
    unawaited(() async {
      // Let playback start first.
      await Future<void>.delayed(const Duration(seconds: 3));
      final service = ref.read(playerServiceProvider);
      final previews = ref.read(previewSourceProvider);
      final points = [
        for (final c in service.tracks.chapters) c.start,
        for (var i = 1; i < 20; i++) duration * (i / 20),
      ];
      for (final at in points) {
        if (run != generation || service.state.source != source) return;
        await previews.frameAt(source, at, duration);
      }
    }());
  });
  ref.onDispose(() {
    generation++;
    unawaited(sub.cancel());
  });
});
