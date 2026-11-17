import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Draws the current video frame. Kyndrel draws its own controls, so
/// media_kit's built-in ones are turned off.
class PlayerVideoView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(playerServiceProvider).backend;
    if (backend is! MediaKitBackend) {
      // Fake backend in tests: just the background.
      return const ColoredBox(color: KyndrelColors.background);
    }
    return Video(
      controller: backend.videoController,
      controls: null,
      fill: KyndrelColors.background,
    );
  }
}
