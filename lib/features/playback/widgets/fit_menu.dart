import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/video_view_settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:material_ui/material_ui.dart';

/// Fit/aspect icon and its popover: fit modes, zoom and rotate (task 2.12).
class FitMenuButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(videoViewProvider);
    final changed =
        view.fit != VideoFit.fit || view.zoom != 1 || view.rotation != 0;
    return Popover(
      align: PopoverAlign.left,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('fit-button'),
        icon: Icons.aspect_ratio,
        tooltip: 'Fit & aspect',
        active: changed,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => const FitMenu(),
    );
  }
}

class FitMenu extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(videoViewProvider);
    final notifier = ref.read(videoViewProvider.notifier);
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('FIT', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          for (final fit in VideoFit.values)
            PopoverOption(
              key: Key('fit-${fit.name}'),
              label: fit.label,
              selected: view.fit == fit,
              onTap: () => unawaited(notifier.setFit(fit)),
            ),
          const SizedBox(height: 12),
          const Text('ZOOM', style: KyndrelTheme.sectionLabel),
          Row(
            children: [
              IconButton(
                key: const Key('zoom-out'),
                tooltip: 'Zoom out',
                onPressed: view.zoom > VideoViewSettings.minZoom
                    ? () => notifier.zoomBy(-VideoViewSettings.zoomStep)
                    : null,
                icon: const Icon(Icons.zoom_out),
              ),
              Expanded(
                child: Text(
                  '${(view.zoom * 100).round()}%',
                  key: const Key('zoom-value'),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const Key('zoom-in'),
                tooltip: 'Zoom in',
                onPressed: view.zoom < VideoViewSettings.maxZoom
                    ? () => notifier.zoomBy(VideoViewSettings.zoomStep)
                    : null,
                icon: const Icon(Icons.zoom_in),
              ),
            ],
          ),
          const Text('ROTATE', style: KyndrelTheme.sectionLabel),
          Row(
            children: [
              IconButton(
                key: const Key('rotate'),
                tooltip: 'Rotate 90° clockwise',
                onPressed: () => unawaited(notifier.rotateClockwise()),
                icon: const Icon(Icons.rotate_right),
              ),
              Expanded(
                child: Text(
                  '${view.rotation}°',
                  key: const Key('rotation-value'),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                key: const Key('view-reset'),
                onPressed: () => unawaited(notifier.reset()),
                child: const Text(
                  'Reset',
                  style: TextStyle(color: KyndrelColors.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
