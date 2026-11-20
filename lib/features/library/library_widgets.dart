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

/// A thumbnail with the length, progress and a badge on it.
class LibraryThumbnail extends StatelessWidget {
  const new({
    required this.path,
    required this.icon,
    this.duration,
    this.progress,
    this.badge,
    super.key,
  });

  final String? path;
  final IconData icon;
  final Duration? duration;
  final double? progress;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = path;
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
              cacheWidth: 320,
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: KyndrelColors.textSecondary),
            )
          else
            Icon(icon, size: 32, color: KyndrelColors.textSecondary),
          if (badge != null)
            PositionedDirectional(
              top: 6,
              start: 6,
              child: LibraryBadge(text: badge!, color: KyndrelColors.accent),
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
        ],
      ),
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
