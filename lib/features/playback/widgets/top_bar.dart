import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/harbor_icon.dart';
import 'package:kyndrel/core/ui/harbor_icons.g.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Back arrow, title with year, quality badge and info button (task 1.3).
/// Sits inside the draggable window title bar.
class TopBarContent extends ConsumerWidget {
  const new({
    required this.onBack,
    required this.onInfo,
    this.compact = false,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onInfo;

  /// Phones: a smaller title and less inset.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (source, width, height) = ref.watch(
      playbackStateProvider.select(
        (s) => (s.value?.source, s.value?.videoWidth, s.value?.videoHeight),
      ),
    );
    if (source == null) return const SizedBox.shrink();

    final audioOnly = ref.watch(
      trackStateProvider.select((t) => t.value?.isAudioOnly ?? false),
    );
    final parsed = parseMediaTitle(source);
    final details = ref.watch(mediaDetailsProvider(source)).value;
    final quality = qualityLabel(width, height);
    final titleText = details?.title.isNotEmpty ?? false
        ? details!.title
        : parsed.title;
    final subtitle =
        details?.subtitle ??
        [
          ?parsed.episode,
          if (parsed.year != null) '${parsed.year}',
        ].join(' · ');

    // Harbor's top bar (task 9.2): a glass back button, then the title
    // (19 px) with its badges and a second line (13 px); tools at the end.
    return Padding(
      padding: EdgeInsetsDirectional.only(start: compact ? 8 : 24, top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassBackButton(onPressed: onBack),
          const SizedBox(width: 12),
          Flexible(
            // Lets drags on the title move the window.
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          titleText,
                          key: const Key('top-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 16 : 19,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: KyndrelColors.titleBarScrim,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (quality != null) ...[
                        const SizedBox(width: 8),
                        QualityBadge(label: quality),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      key: const Key('top-year'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KyndrelColors.textSecondary,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: KyndrelColors.titleBarScrim,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const FullscreenClock(),
          // Decoding matters for pictures, not songs.
          if (!audioOnly) ...[const SizedBox(width: 8), const DecoderButton()],
          const SizedBox(width: 4),
          ControlButton(
            key: const Key('top-info'),
            icon: Icons.info_outline,
            tooltip: context.l10n.mediaInfo,
            size: 20,
            onPressed: onInfo,
          ),
        ],
      ),
    );
  }
}

class QualityBadge extends StatelessWidget {
  const new({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quality-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: KyndrelColors.textSecondary),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: KyndrelColors.textSecondary,
        ),
      ),
    );
  }
}

/// Harbor's back button: a 44 px glass circle with a chevron.
class GlassBackButton extends StatefulWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  State<GlassBackButton> createState() => _GlassBackButtonState();
}

class _GlassBackButtonState extends State<GlassBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.back,
    waitDuration: const Duration(milliseconds: 500),
    child: Semantics(
      button: true,
      label: context.l10n.back,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          key: const Key('top-back'),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? KyndrelColors.controlHover : KyndrelColors.glass,
              border: Border.all(color: KyndrelColors.glassEdge),
            ),
            alignment: Alignment.center,
            child: const HarborIcon(
              HarborIcons.back,
              size: 22,
              color: KyndrelColors.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Harbor's clock in full screen: the time now and when the film ends at
/// this speed (task 9.2). Ticks once a minute, only while shown.
class FullscreenClock extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FullscreenClock> createState() => _FullscreenClockState();
}

class _FullscreenClockState extends ConsumerState<FullscreenClock> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedule() {
    _tick?.cancel();
    final now = clock.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _tick = Timer(next.difference(now), () {
      if (mounted) setState(_schedule);
    });
  }

  @override
  Widget build(BuildContext context) {
    final full = ref.watch(isFullScreenProvider).value ?? false;
    if (!full || !ref.watch(settingsProvider.select((s) => s.showClock))) {
      _tick?.cancel();
      return const SizedBox.shrink();
    }
    if (_tick?.isActive != true) _schedule();
    final (position, duration, rate) = ref.watch(
      playbackStateProvider.select(
        (s) => (
          s.value?.position.inMinutes ?? 0,
          s.value?.duration ?? Duration.zero,
          s.value?.rate ?? 1,
        ),
      ),
    );
    final now = clock.now();
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    String? ends;
    if (duration > Duration.zero && rate > 0) {
      final left = duration - Duration(minutes: position);
      final end = now.add(left * (1 / rate));
      ends = context.l10n.endsAt(time.format(end));
    }
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          key: const Key('fullscreen-clock'),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time.format(now),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (ends != null)
              Text(
                ends,
                style: const TextStyle(
                  fontSize: 12,
                  color: KyndrelColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
