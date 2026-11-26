import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/utils/media_format.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/library/fast_scroller.dart';
import 'package:kyndrel/features/library/library_actions.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:kyndrel/features/library/scene_thumbnail.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// "HD", "FHD", "4K" for a video's height (task 8.6).
String? qualityBadge(int? height) {
  if (height == null) return null;
  if (height >= 2000) return '4K';
  if (height >= 1400) return 'QHD';
  if (height >= 1000) return 'FHD';
  if (height >= 700) return 'HD';
  return null;
}

/// What the fast-scroller's bubble says for [item] in [sort] order.
String scrollLabel(LibraryItem item, LibrarySort sort, String locale) =>
    switch (sort) {
      LibrarySort.name =>
        item.name.isEmpty ? '#' : item.name.characters.first.toUpperCase(),
      LibrarySort.date => DateFormat.yMMM(locale).format(item.added),
      LibrarySort.size => formatBytes(item.size),
      LibrarySort.length =>
        item.durationMs == null
            ? '–'
            : formatDuration(Duration(milliseconds: item.durationMs!)),
    };

/// The folders, with what you were watching above them.
class FolderGrid extends ConsumerWidget {
  const new({required this.folders, required this.progress, super.key});

  final List<FolderSummary> folders;
  final Map<String, HistoryItem> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock.now();
    final l = context.l10n;
    final watching = [
      for (final h in progress.values)
        if (!h.finished && (h.progress ?? 0) > 0.02 && (h.progress ?? 1) < 0.95)
          h,
    ]..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return CustomScrollView(
      key: const Key('library-folders-grid'),
      slivers: [
        if (watching.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(l.libraryContinue, style: _sectionStyle),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: ListView.separated(
                key: const Key('library-continue'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: math.min(watching.length, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final h = watching[i];
                  return SizedBox(
                    width: 176,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        KyndrelTokens.tileRadius,
                      ),
                      onTap: () => unawaited(
                        ref.read(playlistProvider.notifier).open(h.source),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 99,
                            child: LibraryThumbnail(
                              path: h.thumbnailPath,
                              icon: Icons.movie_outlined,
                              progress: h.progress,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            h.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: folders.length,
            itemBuilder: (context, i) => _FolderTile(
              folder: folders[i],
              isNew:
                  now.difference(folders[i].newest) < const Duration(days: 7),
            ),
          ),
        ),
      ],
    );
  }
}

const _sectionStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: KyndrelColors.sectionLabel,
  letterSpacing: KyndrelTokens.sectionLabelLetterSpacing,
);

class _FolderTile extends ConsumerWidget {
  const new({required this.folder, required this.isNew});

  final FolderSummary folder;
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = folder;
    void actions() => unawaited(showFolderActions(context, ref, f, null));
    return Opacity(
      opacity: f.hidden ? 0.5 : 1,
      child: InkWell(
        key: Key('folder-${f.name}'),
        borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
        onTap: () => ref
            .read(videoLibraryProvider.notifier)
            .openFolder(f.path, prefs: f.prefs),
        onLongPress: actions,
        onSecondaryTap: actions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LibraryThumbnail(
                path: f.cover,
                icon: Icons.folder,
                badge: isNew ? context.l10n.libraryNew : null,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (f.pinned)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 4),
                    child: Icon(
                      Icons.push_pin,
                      size: 14,
                      color: KyndrelColors.accent,
                    ),
                  ),
                if (f.private)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 4),
                    child: Icon(Icons.lock, size: 14),
                  ),
                Expanded(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Text(
              '${context.l10n.videoCount(f.count)} · ${formatBytes(f.bytes)}',
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

/// Videos in a list, grid or compact rows, with a fast-scroller.
class VideoList extends ConsumerStatefulWidget {
  const new({
    required this.items,
    required this.view,
    required this.progress,
    super.key,
  });

  final List<LibraryItem> items;
  final VideoLibraryView view;
  final Map<String, HistoryItem> progress;

  /// Row heights, fixed so the fast-scroller's jump costs nothing.
  static const listExtent = 84.0;
  static const compactExtent = 56.0;

  @override
  ConsumerState<VideoList> createState() => _VideoListState();
}

class _VideoListState extends ConsumerState<VideoList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final view = widget.view;
    final progress = widget.progress;
    final now = clock.now();
    final locale = Localizations.localeOf(context).toString();
    String? lastPlayed;
    DateTime? newest;
    for (final h in progress.values) {
      if (newest == null || h.lastPlayedAt.isAfter(newest)) {
        newest = h.lastPlayedAt;
        lastPlayed = h.source;
      }
    }
    final c = ref.read(videoLibraryProvider.notifier);

    Widget tile(BuildContext context, int i) {
      final item = items[i];
      final watched = progress[item.uri];
      return VideoTile(
        key: Key('video-${item.name}'),
        item: item,
        layout: view.layout,
        isNew: isNewItem(item, progress, now),
        progress: isWatched(item, progress) ? 1 : watched?.progress,
        lastPlayed: item.uri == lastPlayed,
        selecting: view.selecting,
        selected: view.selection.contains(item.uri),
        onTap: () => view.selecting
            ? c.toggleSelected(item.uri)
            : unawaited(playFromList(ref, items, item)),
        onSelect: () => c.toggleSelected(item.uri),
        onDetails: () => unawaited(showVideoDetails(context, ref, item)),
      );
    }

    final Widget list = switch (view.layout) {
      LibraryLayout.grid => GridView.builder(
        key: const Key('library-videos'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 32, 24),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: view.gridSize.extent,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: items.length,
        itemBuilder: tile,
      ),
      LibraryLayout.list || LibraryLayout.compact => ListView.builder(
        key: const Key('library-videos'),
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 24),
        itemExtent: view.layout == LibraryLayout.compact
            ? VideoList.compactExtent
            : VideoList.listExtent,
        itemCount: items.length,
        itemBuilder: tile,
      ),
    };
    return FastScroller(
      controller: _scroll,
      itemCount: items.length,
      labelAt: (i) => scrollLabel(items[i], view.sort, locale),
      child: list,
    );
  }
}

/// One video: thumbnail with scene preview and badges, name, details.
class VideoTile extends StatelessWidget {
  const new({
    required this.item,
    required this.layout,
    required this.isNew,
    required this.onTap,
    required this.onSelect,
    required this.onDetails,
    this.progress,
    this.lastPlayed = false,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final LibraryItem item;
  final LibraryLayout layout;
  final bool isNew;
  final double? progress;
  final bool lastPlayed;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;

  /// Long-press: starts or extends a selection, like MX Player.
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final resolution = resolutionLabel(item.width, item.height);
    final meta = [
      ?resolution,
      formatBytes(item.size),
      formatDate(item.added, Localizations.localeOf(context).toString()),
    ].join(' · ');
    final duration = item.durationMs == null
        ? null
        : Duration(milliseconds: item.durationMs!);
    final thumb = SceneThumbnail(
      item: item,
      touch: !selecting,
      child: LibraryThumbnail(
        path: item.thumbnailPath,
        icon: Icons.movie_outlined,
        duration: duration,
        progress: progress,
        badge: isNew ? context.l10n.libraryNew : null,
        quality: layout == LibraryLayout.grid
            ? qualityBadge(item.height)
            : null,
        subtitles: item.hasSubtitles,
        lastPlayed: lastPlayed,
      ),
    );
    final title = Text(
      item.name,
      maxLines: layout == LibraryLayout.compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    final details = Text(
      layout == LibraryLayout.compact && duration != null
          ? '${formatDuration(duration)} · ${formatBytes(item.size)}'
          : meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: KyndrelColors.textSecondary),
    );
    final check = selecting
        ? Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            key: Key('select-${item.name}'),
            color: selected
                ? KyndrelColors.accent
                : KyndrelColors.textSecondary,
          )
        : null;
    final Widget content = switch (layout) {
      LibraryLayout.grid => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumb,
                if (check != null)
                  PositionedDirectional(top: 6, end: 6, child: check),
              ],
            ),
          ),
          const SizedBox(height: 6),
          title,
          details,
        ],
      ),
      LibraryLayout.compact => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            check ??
                Icon(
                  item.hasSubtitles
                      ? Icons.closed_caption_outlined
                      : Icons.movie_outlined,
                  color: lastPlayed
                      ? KyndrelColors.accent
                      : KyndrelColors.textSecondary,
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, details],
              ),
            ),
            if (isNew)
              LibraryBadge(
                text: context.l10n.libraryNew,
                color: KyndrelColors.accent,
              ),
          ],
        ),
      ),
      LibraryLayout.list => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (check != null) ...[check, const SizedBox(width: 12)],
            SizedBox(width: 128, height: 72, child: thumb),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), details],
              ),
            ),
            IconButton(
              key: Key('details-${item.name}'),
              tooltip: context.l10n.libraryDetails,
              icon: const Icon(Icons.more_vert),
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    };
    return Material(
      color: selected ? KyndrelColors.rowActive : Colors.transparent,
      borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
      child: InkWell(
        onTap: onTap,
        onLongPress: onSelect,
        onSecondaryTap: onDetails,
        borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
        child: content,
      ),
    );
  }
}
