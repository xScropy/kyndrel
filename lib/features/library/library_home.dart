import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Start screen: open prompt, continue watching and recent history
/// (task 3.3).
class LibraryHome extends ConsumerWidget {
  const new({
    required this.openPrompt,
    required this.onResume,
    required this.onOpen,
    this.posterFor,
    super.key,
  });

  final Widget openPrompt;

  /// Opens a file and jumps to its saved position.
  final void Function(String source) onResume;
  final void Function(String source) onOpen;

  /// Optional poster/still for a source (task 3.4).
  final ImageProvider? Function(String source)? posterFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuing = ref.watch(continueWatchingProvider).value ?? const [];
    final recent = ref.watch(recentHistoryProvider).value ?? const [];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: openPrompt),
              if (continuing.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  context.l10n.continueWatching,
                  style: KyndrelTheme.sectionLabel,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: continuing.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (_, i) => _ContinueCard(
                      item: continuing[i],
                      poster: posterFor?.call(continuing[i].source),
                      onTap: () => onResume(continuing[i].source),
                    ),
                  ),
                ),
              ],
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(context.l10n.recent, style: KyndrelTheme.sectionLabel),
                    const Spacer(),
                    TextButton(
                      key: const Key('history-clear'),
                      onPressed: () => unawaited(
                        ref.read(historyRepositoryProvider).clear(),
                      ),
                      child: Text(context.l10n.clearHistory),
                    ),
                  ],
                ),
                for (final item in recent.take(10))
                  _RecentRow(item: item, onTap: () => onOpen(item.source)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const new({required this.item, required this.onTap, this.poster});

  final HistoryItem item;
  final ImageProvider? poster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = item.thumbnailPath;
    final details = ref.watch(mediaDetailsProvider(item.source)).value;
    // A real frame first, then the episode still or poster from TMDB.
    final remote = details?.stillUrl ?? details?.posterUrl;
    final image =
        poster ??
        (thumb != null && File(thumb).existsSync()
            ? ResizeImage(FileImage(File(thumb)), width: 480)
            : remote != null
            ? NetworkImage(remote)
            : null);
    final title = details == null
        ? item.title
        : [
            details.title,
            details.subtitle,
          ].where((t) => t.isNotEmpty).join(' · ');
    final left = item.duration - item.position;
    return SizedBox(
      width: 240,
      child: InkWell(
        key: Key('continue-${item.source}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Container(
                    width: 240,
                    height: 135,
                    color: KyndrelColors.surface,
                    child: image == null
                        ? const Icon(
                            Icons.movie_outlined,
                            size: 40,
                            color: KyndrelColors.sectionLabel,
                          )
                        : Image(
                            image: image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    // Watched progress follows the timeline: always LTR.
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: LinearProgressIndicator(
                        value: item.progress ?? 0,
                        minHeight: 4,
                        backgroundColor: KyndrelColors.track,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: IconButton(
                      tooltip: context.l10n.removeFromHistory,
                      iconSize: 16,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x99000000),
                      ),
                      onPressed: () => unawaited(
                        ref.read(historyRepositoryProvider).remove(item.source),
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              item.duration > Duration.zero
                  ? '${formatRemaining(left)} left'
                  : formatDuration(item.position),
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

class _RecentRow extends StatelessWidget {
  const new({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              item.finished ? Icons.check_circle : Icons.play_circle_outline,
              size: 18,
              color: item.finished
                  ? KyndrelColors.accent
                  : KyndrelColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              relativeDate(item.lastPlayedAt),
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

/// "Just now", "5 min ago", "Yesterday", "3 days ago", or the date.
String relativeDate(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(when);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1 && n.day == when.day) return '${d.inHours} h ago';
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(when.year, when.month, when.day)).inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
}
