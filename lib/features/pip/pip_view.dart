import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/native_pip.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/features/pip/pip_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The compact PiP layout: video, drag anywhere to move, double-click to
/// restore, and play/pause + restore buttons on hover (task 4.1).
class PipView extends ConsumerStatefulWidget {
  const new({required this.video, super.key});

  /// The player's video surface (passed in by the app shell).
  final Widget video;

  @override
  ConsumerState<PipView> createState() => _PipViewState();
}

class _PipViewState extends ConsumerState<PipView> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
    );
    final progress = ref.watch(
      playbackStateProvider.select((s) {
        final v = s.value;
        if (v == null || v.duration <= Duration.zero) return 0.0;
        return (v.position.inMilliseconds / v.duration.inMilliseconds).clamp(
          0.0,
          1.0,
        );
      }),
    );
    final pip = ref.read(pipProvider.notifier);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.video,
          GestureDetector(
            key: const Key('pip-surface'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) =>
                unawaited(ref.read(windowServiceProvider).startDragging()),
            onDoubleTap: () => unawaited(pip.exit()),
          ),
          AnimatedOpacity(
            opacity: _hover ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !_hover,
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Stack(
                  children: [
                    Center(
                      child: ControlButton(
                        key: const Key('pip-play'),
                        icon: playing ? Icons.pause : Icons.play_arrow,
                        tooltip: playing ? 'Pause' : 'Play',
                        size: 36,
                        onPressed: () => unawaited(
                          ref.read(playerServiceProvider).playOrPause(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: ControlButton(
                        key: const Key('pip-restore'),
                        icon: Icons.open_in_full,
                        tooltip: 'Back to full window (double-click)',
                        size: 18,
                        onPressed: () => unawaited(pip.exit()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: KyndrelColors.track,
            ),
          ),
        ],
      ),
    );
  }
}

class PipButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In-window PiP needs a movable window; phones get Android's own PiP
    // (task 6.6).
    if (!ref.watch(platformCapabilitiesProvider).hasWindowControls &&
        ref.watch(nativePipProvider) == null) {
      return const SizedBox.shrink();
    }
    return ControlButton(
      key: const Key('pip'),
      icon: Icons.picture_in_picture_alt,
      tooltip: 'Picture in picture (I)',
      onPressed: () => unawaited(ref.read(pipProvider.notifier).enter()),
    );
  }
}
