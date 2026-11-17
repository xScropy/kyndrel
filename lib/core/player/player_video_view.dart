import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/video_view_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Draws the current video frame with the fit and zoom from
/// [videoViewProvider]. Kyndrel draws its own controls, and mpv renders the
/// subtitles into the frame, so media_kit's controls and subtitle overlay are
/// both off.
class PlayerVideoView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(playerServiceProvider).backend;
    final view = ref.watch(videoViewProvider);
    final controller = backend is MediaKitBackend
        ? backend.videoController
        : null;
    if (controller == null) {
      // Fake backend in tests: just the background.
      return const ColoredBox(color: KyndrelColors.background);
    }
    return ClipRect(
      child: Transform.scale(
        scale: view.zoom,
        child: Video(
          controller: controller,
          controls: null,
          fill: KyndrelColors.background,
          fit: switch (view.fit) {
            VideoFit.fill => BoxFit.cover,
            VideoFit.stretch => BoxFit.fill,
            VideoFit.original => BoxFit.none,
            _ => BoxFit.contain,
          },
          subtitleViewConfiguration: const SubtitleViewConfiguration(
            visible: false,
          ),
        ),
      ),
    );
  }
}
