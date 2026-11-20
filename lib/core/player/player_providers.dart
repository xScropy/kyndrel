import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/subtitle_fonts.dart';

/// The app's one [PlayerService]. Override it in tests with a fake backend.
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService(
    MediaKitBackend(subtitleFontsDir: ref.watch(subtitleFontsDirProvider)),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Full playback snapshot. Rebuilds on every change, including position, so
/// prefer `.select` or the narrower providers below where possible.
final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(playerServiceProvider).states,
);

final playbackStatusProvider = StreamProvider<PlaybackStatus>(
  (ref) => ref.watch(playerServiceProvider).status,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playerServiceProvider).position,
);

final durationProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playerServiceProvider).duration,
);

final bufferingProvider = StreamProvider<bool>(
  (ref) => ref.watch(playerServiceProvider).buffering,
);

final trackStateProvider = StreamProvider<TrackState>(
  (ref) => ref.watch(playerServiceProvider).trackStates,
);
