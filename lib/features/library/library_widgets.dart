import 'dart:io';

import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:material_ui/material_ui.dart';

/// Pieces the video and music libraries share (tasks 7.4, 7.5).

/// An empty or blocked library: an icon, a line and maybe a button.
class LibraryMessage extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    this.action,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) => ListView(
    // Scrollable, so pull-to-refresh works on an empty library too.
    padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
    children: [
      Icon(icon, size: 56, color: KyndrelColors.textSecondary),
      const SizedBox(height: 16),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: KyndrelColors.textSecondary),
      ),
      if (busy) ...[
        const SizedBox(height: 16),
        const Center(
          child: CircularProgressIndicator(color: KyndrelColors.accent),
        ),
      ],
      if (action != null) ...[
        const SizedBox(height: 16),
        Center(child: action),
      ],
    ],
  );
}

/// A thumbnail with the length, progress and badges on it.
///
/// Decoded at the size it is shown (task 8.6), so a grid of small tiles
/// holds small images, and faded in when ready instead of popping.
class LibraryThumbnail extends StatelessWidget {
  const new({
    required this.path,
    required this.icon,
    this.duration,
    this.progress,
    this.badge,
    this.quality,
    this.subtitles = false,
    this.lastPlayed = false,
    super.key,
  });

  final String? path;
  final IconData icon;
  final Duration? duration;
  final double? progress;
  final String? badge;

  /// "HD", "4K": top end corner.
  final String? quality;

  /// A subtitle file sits beside it.
  final bool subtitles;

  /// The video played most recently: an orange edge.
  final bool lastPlayed;

  @override
  Widget build(BuildContext context) {
    final p = path;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rounded up to 64 px steps so similar tiles share decoded images.
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 320;
        final decodeWidth = ((w * dpr / 64).ceil() * 64).clamp(64, 640);
        return ClipRRect(
          borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: KyndrelColors.surface),
              if (p != null)
                Image.file(
                  File(p),
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidth,
                  frameBuilder: (context, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: child,
                        ),
                  errorBuilder: (_, _, _) =>
                      Icon(icon, color: KyndrelColors.textSecondary),
                )
              else
                Icon(icon, size: 32, color: KyndrelColors.textSecondary),
              if (badge != null)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: LibraryBadge(
                    text: badge!,
                    color: KyndrelColors.accent,
                  ),
                ),
              if (quality != null || subtitles)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subtitles)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4),
                          child: LibraryBadge(
                            text: 'CC',
                            color: Color(0xCC000000),
                          ),
                        ),
                      if (quality != null)
                        LibraryBadge(
                          text: quality!,
                          color: const Color(0xCC000000),
                        ),
                    ],
                  ),
                ),
              if (duration != null)
                PositionedDirectional(
                  bottom: 6,
                  end: 6,
                  child: LibraryBadge(
                    text: formatDuration(duration!),
                    color: const Color(0xCC000000),
                  ),
                ),
              if (progress != null && progress! > 0)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    color: KyndrelColors.accent,
                    backgroundColor: const Color(0x66000000),
                  ),
                ),
              if (lastPlayed)
                DecoratedBox(
                  key: const Key('last-played'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      KyndrelTokens.tileRadius,
                    ),
                    border: Border.all(color: KyndrelColors.accent, width: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A small label on a thumbnail (length, NEW).
class LibraryBadge extends StatelessWidget {
  const new({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KyndrelTokens.badgeRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: KyndrelColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}
