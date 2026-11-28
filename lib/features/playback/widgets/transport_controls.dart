import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/harbor_icon.dart';
import 'package:kyndrel/core/ui/harbor_icons.g.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Harbor's middle group (task 9.2): ‹‹ Previous, back N s, play/pause,
/// forward N s, Next ››. N comes from settings; the episode buttons show
/// when the queue has more than one file.
class TransportControls extends ConsumerWidget {
  const new({this.compact = false, super.key});

  /// Phones: icon-only episode buttons and a smaller play button.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skip = ref.watch(settingsProvider.select((s) => s.skipSeconds));
    final service = ref.read(playerServiceProvider);
    final offset = Duration(seconds: skip);
    final queue = ref.watch(playlistProvider);
    final playlist = ref.read(playlistProvider.notifier);
    final showQueue = queue.items.length > 1;
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showQueue)
          EpisodeNavButton(
            key: const Key('previous'),
            forward: false,
            label: l.previous,
            tooltip: l.previousTooltip,
            iconOnly: compact,
            onPressed: () => unawaited(playlist.previous()),
          ),
        SeekStepButton(
          key: const Key('skip-back'),
          seconds: skip,
          forward: false,
          tooltip: l.backSeconds(skip),
          onPressed: () => unawaited(service.seekBy(-offset)),
        ),
        const SizedBox(width: 6),
        PlayPauseButton(size: compact ? 56 : 64),
        const SizedBox(width: 6),
        SeekStepButton(
          key: const Key('skip-forward'),
          seconds: skip,
          forward: true,
          tooltip: l.forwardSeconds(skip),
          onPressed: () => unawaited(service.seekBy(offset)),
        ),
        if (showQueue)
          EpisodeNavButton(
            key: const Key('next'),
            forward: true,
            label: l.next,
            tooltip: l.nextTooltip,
            iconOnly: compact,
            onPressed: queue.hasNext ? () => unawaited(playlist.next()) : null,
          ),
      ],
    );
  }
}

/// Harbor's "‹‹ Previous" / "Next ››": a pill with the label, or just the
/// chevrons when space is short.
class EpisodeNavButton extends StatefulWidget {
  const new({
    required this.forward,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.iconOnly = false,
    super.key,
  });

  final bool forward;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool iconOnly;

  @override
  State<EpisodeNavButton> createState() => _EpisodeNavButtonState();
}

class _EpisodeNavButtonState extends State<EpisodeNavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled
        ? (_hover ? KyndrelColors.textPrimary : KyndrelColors.controlIdle)
        : KyndrelColors.textPrimary.withValues(alpha: 0.25);
    final icon = HarborIcon(
      widget.forward ? HarborIcons.nextEpisode : HarborIcons.prevEpisode,
      size: widget.iconOnly ? 22 : 20,
      color: color,
    );
    final text = Text(
      widget.label,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
    );
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              constraints: const BoxConstraints(minWidth: 44),
              margin: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : 4),
              padding: EdgeInsets.symmetric(
                horizontal: widget.iconOnly ? 0 : 14,
              ),
              decoration: BoxDecoration(
                color: _hover && enabled
                    ? KyndrelColors.controlHover
                    : KyndrelColors.scrimClear,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.forward) icon,
                  if (!widget.iconOnly) ...[
                    if (!widget.forward) const SizedBox(width: 6),
                    text,
                    if (widget.forward) const SizedBox(width: 6),
                  ],
                  if (widget.forward) icon,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Harbor's seek-step button: the circular arrow with the seconds, which
/// swings 40° the way it seeks when pressed.
class SeekStepButton extends StatefulWidget {
  const new({
    required this.seconds,
    required this.forward,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final int seconds;
  final bool forward;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<SeekStepButton> createState() => _SeekStepButtonState();
}

class _SeekStepButtonState extends State<SeekStepButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Harbor's glyph has "10" drawn in; other lengths use the arrow with
    // the number on top.
    final glyph = widget.seconds == 10
        ? HarborIcon(
            widget.forward ? HarborIcons.seekForward : HarborIcons.seekBack,
            size: 30,
          )
        : SkipIcon(seconds: widget.seconds, forward: widget.forward);
    return ControlButton(
      icon: widget.forward ? Icons.forward : Icons.replay,
      tooltip: widget.tooltip,
      onPressed: () {
        _nudge.forward(from: 0);
        widget.onPressed();
      },
      child: AnimatedBuilder(
        animation: _nudge,
        builder: (context, child) {
          // 0 → ±40° → 0 with Harbor's overshooting curve.
          final t = _nudge.value;
          final swing = t < 0.4 ? t / 0.4 : 1 - (t - 0.4) / 0.6;
          final eased = const Cubic(
            0.34,
            1.56,
            0.64,
            1,
          ).transform(swing.clamp(0.0, 1.0));
          final angle = (widget.forward ? 1 : -1) * 40 * eased * math.pi / 180;
          return Transform.rotate(angle: angle, child: child);
        },
        child: IconTheme.merge(
          data: const IconThemeData(color: KyndrelColors.controlIdle),
          child: glyph,
        ),
      ),
    );
  }
}

/// Circular arrow with the skip length inside (lengths other than 10 s).
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

/// Harbor's play/pause: a large clear circle (64 px) with the outlined
/// glyph, a faint circle on hover, a little press.
class PlayPauseButton extends ConsumerStatefulWidget {
  const new({this.size = 64, super.key});

  final double size;

  @override
  ConsumerState<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends ConsumerState<PlayPauseButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
    );
    final l = context.l10n;
    final iconSize = widget.size >= 64 ? 36.0 : 32.0;
    return Tooltip(
      message: playing ? l.pauseTooltip : l.playTooltip,
      child: Semantics(
        button: true,
        label: playing ? l.pause : l.play,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: InkResponse(
            key: const Key('play-pause'),
            radius: widget.size / 2,
            focusColor: KyndrelColors.focus,
            hoverColor: KyndrelColors.scrimClear,
            highlightColor: KyndrelColors.scrimClear,
            splashColor: KyndrelColors.controlHover,
            onHighlightChanged: (v) => setState(() => _down = v),
            onTap: () =>
                unawaited(ref.read(playerServiceProvider).playOrPause()),
            child: AnimatedScale(
              scale: _down ? 0.95 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hover
                      ? KyndrelColors.controlHover
                      : KyndrelColors.scrimClear,
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1).animate(a),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: HarborIcon(
                    // Harbor's file names are the glyphs: while playing,
                    // the button offers pause.
                    playing
                        ? HarborIcons.playPausePaused
                        : HarborIcons.playPausePlaying,
                    key: ValueKey(playing),
                    size: iconSize,
                    color: KyndrelColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
