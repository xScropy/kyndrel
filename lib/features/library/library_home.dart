import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/metadata/media_details.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Start screen in Harbor's style (task 9.16): a search pill, a large
/// hero for the video to pick up again, then rows of big rounded cards
/// (continue watching, recently added) and the history. With nothing
/// played yet, the hero holds the open prompt.
class LibraryHome extends ConsumerStatefulWidget {
  const new({
    required this.openPrompt,
    required this.onResume,
    required this.onOpen,
    this.posterFor,
    this.onOpenSettings,
    super.key,
  });

  final Widget openPrompt;

  /// Opens a file and jumps to its saved position.
  final void Function(String source) onResume;
  final void Function(String source) onOpen;

  /// Optional poster/still for a source (task 3.4).
  final ImageProvider? Function(String source)? posterFor;

  /// Phones have no sidebar: a gear by the search opens Settings.
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<LibraryHome> {
  int _hero = 0;

  ImageProvider? _image(String source, String? thumb, MediaDetails? d) {
    final poster = widget.posterFor?.call(source);
    if (poster != null) return poster;
    if (thumb != null && File(thumb).existsSync()) {
      return ResizeImage(FileImage(File(thumb)), width: 960);
    }
    final remote = d?.stillUrl ?? d?.posterUrl;
    return remote == null ? null : NetworkImage(remote);
  }

  void _search(String query) {
    ref.read(videoLibraryProvider.notifier)
      ..show(LibraryMode.all)
      ..search(query);
    ref.read(librarySectionProvider.notifier).show(LibrarySection.videos);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final continuing = ref.watch(continueWatchingProvider).value ?? const [];
    final recent = ref.watch(recentHistoryProvider).value ?? const [];
    final added =
        ref
            .watch(
              libraryListProvider((
                folder: null,
                sort: LibrarySort.date,
                descending: true,
                filter: const LibraryFilter(),
              )),
            )
            .value ??
        const <LibraryItem>[];
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final pad = compact ? 16.0 : 40.0;
    final heroItems = continuing.take(5).toList();
    final hero = heroItems.isEmpty
        ? null
        : heroItems[_hero.clamp(0, heroItems.length - 1)];

    return CustomScrollView(
      key: const Key('library-home'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, compact ? 56 : 64, pad, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Center(child: _SearchPill(onSubmitted: _search)),
                ),
                if (widget.onOpenSettings != null && compact) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('home-settings'),
                    tooltip: l.settings,
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
          sliver: SliverToBoxAdapter(
            child: hero == null
                ? _OpenHero(prompt: widget.openPrompt, compact: compact)
                : _Hero(
                    item: hero,
                    image: _image(
                      hero.source,
                      hero.thumbnailPath,
                      ref.watch(mediaDetailsProvider(hero.source)).value,
                    ),
                    details: ref.watch(mediaDetailsProvider(hero.source)).value,
                    compact: compact,
                    onResume: () => widget.onResume(hero.source),
                    onStartOver: () => widget.onOpen(hero.source),
                  ),
          ),
        ),
        if (heroItems.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _Dots(
                count: heroItems.length,
                index: _hero.clamp(0, heroItems.length - 1),
                onTap: (i) => setState(() => _hero = i),
              ),
            ),
          ),
        if (continuing.isNotEmpty)
          _Row(
            title: l.homeContinueTitle,
            pad: pad,
            height: compact ? 206 : 240,
            count: continuing.length,
            item: (i) => _ContinueCard(
              item: continuing[i],
              compact: compact,
              image: _image(
                continuing[i].source,
                continuing[i].thumbnailPath,
                ref.watch(mediaDetailsProvider(continuing[i].source)).value,
              ),
              onTap: () => widget.onResume(continuing[i].source),
            ),
          ),
        if (added.isNotEmpty)
          _Row(
            title: l.homeRecentlyAdded,
            pad: pad,
            height: compact ? 160 : 186,
            count: added.length.clamp(0, 16),
            item: (i) => _AddedCard(
              item: added[i],
              compact: compact,
              isNew: isNewItem(added[i], {
                for (final h in recent) h.source: h,
              }, DateTime.now()),
              onTap: () => unawaited(playFromList(ref, added, added[i])),
            ),
          ),
        if (continuing.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 32, pad, 0),
            sliver: SliverToBoxAdapter(child: Center(child: widget.openPrompt)),
          ),
        if (recent.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 32, pad, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(l.homeHistory, style: _rowTitle),
                  const Spacer(),
                  TextButton(
                    key: const Key('history-clear'),
                    onPressed: () =>
                        unawaited(ref.read(historyRepositoryProvider).clear()),
                    child: Text(l.clearHistory),
                  ),
                ],
              ),
            ),
          ),
        if (recent.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 40),
            sliver: SliverList.list(
              children: [
                for (final item in recent.take(10))
                  _RecentRow(
                    item: item,
                    onTap: () => widget.onOpen(item.source),
                  ),
              ],
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

const _rowTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: KyndrelColors.textPrimary,
);

/// Harbor's search: a wide glass pill at the top.
class _SearchPill extends StatelessWidget {
  const new({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 448),
    child: SizedBox(
      height: 44,
      child: TextField(
        key: const Key('home-search'),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) onSubmitted(v.trim());
        },
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: context.l10n.homeSearchHint,
          hintStyle: const TextStyle(color: KyndrelColors.sectionLabel),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: KyndrelColors.sectionLabel,
          ),
          filled: true,
          fillColor: KyndrelColors.controlHover,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: KyndrelColors.panelBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: KyndrelColors.panelBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: KyndrelColors.trackBuffered),
          ),
        ),
      ),
    ),
  );
}

/// Harbor's hero: the picture across the card, darkened towards the text,
/// a chip, the big title, details and two pill buttons.
class _Hero extends StatelessWidget {
  const new({
    required this.item,
    required this.image,
    required this.details,
    required this.compact,
    required this.onResume,
    required this.onStartOver,
  });

  final HistoryItem item;
  final ImageProvider? image;
  final MediaDetails? details;
  final bool compact;
  final VoidCallback onResume;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = details?.title.isNotEmpty ?? false
        ? details!.title
        : item.title;
    final subtitle = details?.subtitle ?? '';
    final left = item.duration - item.position;
    final meta = [
      if (subtitle.isNotEmpty) subtitle,
      if (item.duration > Duration.zero) l.homeLeft(formatRemaining(left)),
    ].join('  ·  ');
    return ClipRRect(
      key: Key('hero-${item.source}'),
      borderRadius: BorderRadius.circular(compact ? 18 : 24),
      // At least the hero's shape; taller when the text needs it.
      child: LayoutBuilder(
        builder: (context, c) => ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: c.maxWidth / (compact ? 16 / 10 : 21 / 8.5),
          ),
          child: Stack(
            alignment: AlignmentDirectional.bottomStart,
            children: [
              const Positioned.fill(
                child: ColoredBox(color: KyndrelColors.surface),
              ),
              if (image != null)
                Positioned.fill(
                  child: Image(
                    image: image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        KyndrelColors.scrimBottom,
                        KyndrelColors.scrimMiddle,
                        KyndrelColors.scrimClear,
                      ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        KyndrelColors.scrimTop,
                        KyndrelColors.scrimClear,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 18 : 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: KyndrelColors.glass,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            size: 14,
                            color: KyndrelColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.homeChip,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 18),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 26 : 52,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: compact ? -0.3 : -1,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: compact ? 13 : 15,
                          color: KyndrelColors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 14 : 26),
                    // Watched so far.
                    if (item.progress case final p?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: SizedBox(
                          width: compact ? 160 : 240,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: p,
                                minHeight: 4,
                                backgroundColor: KyndrelColors.track,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('hero-resume'),
                          style: FilledButton.styleFrom(
                            backgroundColor: KyndrelColors.textPrimary,
                            foregroundColor: KyndrelColors.onAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: onResume,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            l.homeResume,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('hero-restart'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KyndrelColors.textPrimary,
                            side: const BorderSide(
                              color: KyndrelColors.glassBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 16,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: onStartOver,
                          icon: const Icon(Icons.replay, size: 18),
                          label: Text(l.homeStartOver),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No history yet: the open prompt, framed like the hero.
class _OpenHero extends StatelessWidget {
  const new({required this.prompt, required this.compact});

  final Widget prompt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      key: const Key('home-open-hero'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 40,
        vertical: compact ? 24 : 48,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        border: Border.all(color: KyndrelColors.panelBorder),
        gradient: const RadialGradient(
          center: AlignmentDirectional.topStart,
          radius: 1.4,
          colors: [KyndrelColors.rowActive, KyndrelColors.surface],
        ),
      ),
      child: Column(
        children: [
          Text(
            l.homeOpenTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 26 : 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.homeOpenSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KyndrelColors.textSecondary),
          ),
          const SizedBox(height: 24),
          prompt,
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const new({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        GestureDetector(
          key: Key('hero-dot-$i'),
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: i == index ? 48 : 22,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? KyndrelColors.textPrimary
                  : KyndrelColors.trackBuffered,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
    ],
  );
}

/// A titled horizontal row of cards.
class _Row extends StatelessWidget {
  const new({
    required this.title,
    required this.pad,
    required this.height,
    required this.count,
    required this.item,
  });

  final String title;
  final double pad;
  final double height;
  final int count;
  final Widget Function(int) item;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Text(title, style: _rowTitle),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: pad),
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, i) => item(i),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A 16:9 picture with rounded corners, or a placeholder.
class _Picture extends StatelessWidget {
  const new({required this.image, required this.width});

  final ImageProvider? image;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 9 / 16,
    color: KyndrelColors.surface,
    child: image == null
        ? const Icon(
            Icons.movie_outlined,
            size: 36,
            color: KyndrelColors.sectionLabel,
          )
        : Image(
            image: image!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
  );
}

class _ContinueCard extends ConsumerWidget {
  const new({
    required this.item,
    required this.image,
    required this.onTap,
    required this.compact,
  });

  final HistoryItem item;
  final ImageProvider? image;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(mediaDetailsProvider(item.source)).value;
    final width = compact ? 260.0 : 320.0;
    final title = details == null
        ? item.title
        : [
            details.title,
            details.subtitle,
          ].where((t) => t.isNotEmpty).join(' · ');
    final left = item.duration - item.position;
    return SizedBox(
      width: width,
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
                  _Picture(image: image, width: width),
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
                    top: 6,
                    end: 6,
                    child: IconButton(
                      tooltip: context.l10n.removeFromHistory,
                      iconSize: 16,
                      style: IconButton.styleFrom(
                        backgroundColor: KyndrelColors.glass,
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
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              item.duration > Duration.zero
                  ? context.l10n.homeLeft(formatRemaining(left))
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

class _AddedCard extends StatelessWidget {
  const new({
    required this.item,
    required this.onTap,
    required this.compact,
    required this.isNew,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final bool compact;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 200.0 : 240.0;
    final thumb = item.thumbnailPath;
    final image = thumb != null && File(thumb).existsSync()
        ? ResizeImage(FileImage(File(thumb)), width: 480)
        : null;
    return SizedBox(
      width: width,
      child: InkWell(
        key: Key('added-${item.uri}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  _Picture(image: image, width: width),
                  if (isNew)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: KyndrelColors.titleBarScrim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title ?? item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
