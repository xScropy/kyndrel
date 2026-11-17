import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:material_ui/material_ui.dart';

/// Back N s, play/pause, forward N s (task 1.5). N comes from settings.
class TransportControls extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skip = ref.watch(settingsProvider.select((s) => s.skipSeconds));
    final service = ref.read(playerServiceProvider);
    final offset = Duration(seconds: skip);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ControlButton(
          key: const Key('skip-back'),
          icon: Icons.replay,
          tooltip: 'Back $skip s',
          onPressed: () => unawaited(service.seekBy(-offset)),
          child: SkipIcon(seconds: skip, forward: false),
        ),
        const SizedBox(width: 12),
        const PlayPauseButton(),
        const SizedBox(width: 12),
        ControlButton(
          key: const Key('skip-forward'),
          icon: Icons.forward,
          tooltip: 'Forward $skip s',
          onPressed: () => unawaited(service.seekBy(offset)),
          child: SkipIcon(seconds: skip, forward: true),
        ),
      ],
    );
  }
}

/// Circular arrow with the skip length inside.
class SkipIcon extends StatelessWidget {
  const new({required this.seconds, required this.forward, super.key});

  final int seconds;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final icon = Transform.flip(
      flipX: forward,
      child: const Icon(Icons.replay, size: 30),
    );
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          icon,
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '$seconds',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large round play/pause button with an animated icon.
class PlayPauseButton extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends ConsumerState<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
    );
    unawaited(playing ? _anim.forward() : _anim.reverse());
    return Tooltip(
      message: playing ? 'Pause (Space)' : 'Play (Space)',
      child: Semantics(
        button: true,
        label: playing ? 'Pause' : 'Play',
        child: Material(
          color: KyndrelColors.accent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('play-pause'),
            customBorder: const CircleBorder(),
            onTap: () =>
                unawaited(ref.read(playerServiceProvider).playOrPause()),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _anim,
                  size: 30,
                  color: KyndrelColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
