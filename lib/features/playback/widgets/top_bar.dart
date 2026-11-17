import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:material_ui/material_ui.dart';

/// Back arrow, title with year, quality badge and info button (task 1.3).
/// Sits inside the draggable window title bar.
class TopBarContent extends ConsumerWidget {
  const new({required this.onBack, required this.onInfo, super.key});

  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (source, width, height) = ref.watch(
      playbackStateProvider.select(
        (s) => (s.value?.source, s.value?.videoWidth, s.value?.videoHeight),
      ),
    );
    if (source == null) return const SizedBox.shrink();

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

    return Row(
      children: [
        const SizedBox(width: 4),
        ControlButton(
          key: const Key('top-back'),
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Flexible(
          // Lets drags on the title move the window.
          child: IgnorePointer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  key: const Key('top-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    key: const Key('top-year'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: KyndrelColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (quality != null) ...[
          const SizedBox(width: 12),
          IgnorePointer(child: QualityBadge(label: quality)),
        ],
        const SizedBox(width: 4),
        ControlButton(
          key: const Key('top-info'),
          icon: Icons.info_outline,
          tooltip: 'Media info',
          size: 20,
          onPressed: onInfo,
        ),
      ],
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
