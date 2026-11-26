import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/platform/folder_access.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_watcher.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/core/utils/media_format.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum LibrarySort { date, name, size, length }

enum LibraryLayout { list, grid }

/// What the video library shows (task 7.4).
@immutable
class VideoLibraryView {
  const new({
    this.folder,
    this.sort = LibrarySort.date,
    this.layout = LibraryLayout.list,
    this.query = '',
    this.allVideos = false,
  });

  /// The open folder's path; null shows the folders.
  final String? folder;
  final LibrarySort sort;
  final LibraryLayout layout;
  final String query;

  /// Every video in one list instead of folders.
  final bool allVideos;

  VideoLibraryView copyWith({
    String? Function()? folder,
    LibrarySort? sort,
    LibraryLayout? layout,
    String? query,
    bool? allVideos,
  }) => VideoLibraryView(
    folder: folder != null ? folder() : this.folder,
    sort: sort ?? this.sort,
    layout: layout ?? this.layout,
    query: query ?? this.query,
    allVideos: allVideos ?? this.allVideos,
  );
}

class VideoLibraryController extends Notifier<VideoLibraryView> {
  @override
  VideoLibraryView build() => const VideoLibraryView();

  void openFolder(String path) => state = state.copyWith(folder: () => path);

  void back() => state = state.copyWith(folder: () => null);

  void sortBy(LibrarySort sort) => state = state.copyWith(sort: sort);

  void setLayout(LibraryLayout layout) =>
      state = state.copyWith(layout: layout);

  void search(String query) => state = state.copyWith(query: query);

  void showAll({required bool value}) =>
      state = state.copyWith(allVideos: value, folder: () => null);
}

final videoLibraryProvider =
    NotifierProvider<VideoLibraryController, VideoLibraryView>(
      VideoLibraryController.new,
    );

/// A folder of videos.
@immutable
class MediaFolder {
  const new(this.path, this.name, this.items);

  final String path;
  final String name;

  /// Newest first.
  final List<LibraryItem> items;

  int get size => items.fold(0, (s, i) => s + i.size);
}

/// Folders with their videos, the most recently added folder first.
List<MediaFolder> groupByFolder(List<LibraryItem> items) {
  final groups = <String, List<LibraryItem>>{};
  for (final i in items) {
    (groups[i.folderPath] ??= []).add(i);
  }
  final folders = [
    for (final e in groups.entries)
      MediaFolder(
        e.key,
        e.value.first.folder,
        e.value..sort((a, b) => b.added.compareTo(a.added)),
      ),
  ]..sort((a, b) => b.items.first.added.compareTo(a.items.first.added));
  return folders;
}

List<LibraryItem> sortItems(List<LibraryItem> items, LibrarySort sort) {
  final out = [...items];
  switch (sort) {
    case LibrarySort.date:
      out.sort((a, b) => b.added.compareTo(a.added));
    case LibrarySort.name:
      out.sort((a, b) => compareNatural(a.name, b.name));
    case LibrarySort.size:
      out.sort((a, b) => b.size.compareTo(a.size));
    case LibrarySort.length:
      out.sort((a, b) => (b.durationMs ?? 0).compareTo(a.durationMs ?? 0));
  }
  return out;
}

/// "NEW": added in the last week and never played.
bool isNewItem(
  LibraryItem item,
  Map<String, HistoryItem> progress,
  DateTime now,
) =>
    !progress.containsKey(item.uri) &&
    now.difference(item.added) < const Duration(days: 7);

/// Plays [item] with the rest of [list] queued after it.
Future<void> playFromList(
  WidgetRef ref,
  List<LibraryItem> list,
  LibraryItem item,
) => ref.read(playlistProvider.notifier).openAll([
  for (final i in list) i.uri,
], start: list.indexOf(item));

/// Scans once per session, the first time a library tab is shown, then
/// keeps the library up to date (folder watching, task 8.5).
final libraryAutoScanProvider = Provider<void>((ref) {
  unawaited(ref.read(mediaIndexProvider).refresh(ask: true));
  ref.watch(libraryWatcherProvider);
});

/// The Videos tab: folders, then the videos in a folder, like a phone
/// video player (task 7.4).
class VideoLibrary extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryAutoScanProvider);
    final view = ref.watch(videoLibraryProvider);
    final items =
        ref.watch(libraryItemsProvider(MediaKind.video)).value ?? const [];
    final status =
        ref.watch(mediaIndexStatusProvider).value ?? const MediaIndexStatus();
    final progress = ref.watch(watchProgressProvider).value ?? const {};
    final controller = ref.read(videoLibraryProvider.notifier);
    final l = context.l10n;

    final query = view.query.trim().toLowerCase();
    final folders = groupByFolder(items);
    final openFolder = view.folder == null
        ? null
        : folders.where((f) => f.path == view.folder).firstOrNull;

    Widget body;
    if (!status.granted) {
      body = LibraryMessage(
        key: const Key('library-allow'),
        icon: Icons.video_library_outlined,
        text: l.libraryAllowTitle,
        action: FilledButton(
          onPressed: () =>
              unawaited(ref.read(mediaIndexProvider).refresh(ask: true)),
          child: Text(l.libraryAllow),
        ),
      );
    } else if (items.isEmpty) {
      body = LibraryMessage(
        key: const Key('library-empty'),
        icon: Icons.video_library_outlined,
        text: status.scanning ? l.libraryScanning : l.libraryEmptyVideos,
        busy: status.scanning,
        action: Platform.isAndroid
            ? null
            : OutlinedButton.icon(
                onPressed: () => unawaited(showLibraryFolders(context)),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(l.libraryManageFolders),
              ),
      );
    } else if (query.isNotEmpty || view.allVideos || openFolder != null) {
      final source = openFolder?.items ?? items;
      final shown = sortItems(
        query.isEmpty
            ? source
            : [
                for (final i in source)
                  if (i.name.toLowerCase().contains(query)) i,
              ],
        view.sort,
      );
      body = shown.isEmpty
          ? LibraryMessage(icon: Icons.search_off, text: l.libraryNoMatch)
          : _VideoList(items: shown, layout: view.layout, progress: progress);
    } else {
      body = _FolderGrid(folders: folders, progress: progress);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: openFolder?.name ?? l.libraryVideos,
          subtitle: openFolder == null
              ? null
              : l.videoCount(openFolder.items.length),
          onBack: openFolder == null ? null : controller.back,
          view: view,
          scanning: status.scanning || status.toProbe > 0,
        ),
        Expanded(
          child: RefreshIndicator(
            color: KyndrelColors.accent,
            onRefresh: () => ref.read(mediaIndexProvider).refresh(ask: true),
            child: body,
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.view,
    required this.scanning,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VideoLibraryView view;
  final bool scanning;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  late final _search = TextEditingController(text: widget.view.query);
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = ref.read(videoLibraryProvider.notifier);
    final view = widget.view;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              key: const Key('library-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: widget.onBack,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: _searching
                ? TextField(
                    key: const Key('library-search-field'),
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l.librarySearch,
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: c.search,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: KyndrelColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
          ),
          if (widget.scanning)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: KyndrelColors.accent,
                ),
              ),
            ),
          IconButton(
            key: const Key('library-search'),
            tooltip: l.librarySearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                c.search('');
              }
            }),
          ),
          if (widget.onBack == null)
            IconButton(
              key: const Key('library-all'),
              tooltip: view.allVideos ? l.libraryFolders : l.libraryAllVideos,
              icon: Icon(
                view.allVideos ? Icons.folder_outlined : Icons.video_library,
              ),
              onPressed: () => c.showAll(value: !view.allVideos),
            ),
          PopupMenuButton<Object>(
            key: const Key('library-menu'),
            tooltip: l.librarySort,
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              if (v is LibrarySort) c.sortBy(v);
              if (v is LibraryLayout) c.setLayout(v);
              if (v == 'folders') unawaited(showLibraryFolders(context));
            },
            itemBuilder: (_) => [
              for (final (s, label) in [
                (LibrarySort.date, l.sortDate),
                (LibrarySort.name, l.sortName),
                (LibrarySort.size, l.sortSize),
                (LibrarySort.length, l.sortLength),
              ])
                CheckedPopupMenuItem(
                  key: Key('sort-${s.name}'),
                  value: s,
                  checked: view.sort == s,
                  child: Text(label),
                ),
              const PopupMenuDivider(),
              for (final (layout, label) in [
                (LibraryLayout.list, l.layoutList),
                (LibraryLayout.grid, l.layoutGrid),
              ])
                CheckedPopupMenuItem(
                  key: Key('layout-${layout.name}'),
                  value: layout,
                  checked: view.layout == layout,
                  child: Text(label),
                ),
              if (!Platform.isAndroid) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: const Key('library-folders'),
                  value: 'folders',
                  child: Text(l.libraryManageFolders),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderGrid extends ConsumerWidget {
  const new({required this.folders, required this.progress});

  final List<MediaFolder> folders;
  final Map<String, HistoryItem> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock.now();
    return GridView.builder(
      key: const Key('library-folders-grid'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final f = folders[i];
        final newCount = f.items
            .where((v) => isNewItem(v, progress, now))
            .length;
        return InkWell(
          key: Key('folder-${f.name}'),
          borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
          onTap: () =>
              ref.read(videoLibraryProvider.notifier).openFolder(f.path),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LibraryThumbnail(
                  path: f.items.first.thumbnailPath,
                  icon: Icons.folder,
                  badge: newCount > 0 ? context.l10n.libraryNew : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${context.l10n.videoCount(f.items.length)} · '
                '${formatBytes(f.size)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: KyndrelColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoList extends ConsumerWidget {
  const new({
    required this.items,
    required this.layout,
    required this.progress,
  });

  final List<LibraryItem> items;
  final LibraryLayout layout;
  final Map<String, HistoryItem> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock.now();
    Widget tile(BuildContext context, int i) {
      final item = items[i];
      final watched = progress[item.uri];
      return _VideoTile(
        key: Key('video-${item.name}'),
        item: item,
        grid: layout == LibraryLayout.grid,
        isNew: isNewItem(item, progress, now),
        progress: watched?.finished ?? false ? 1 : watched?.progress,
        onTap: () => unawaited(playFromList(ref, items, item)),
        onDetails: () => unawaited(showVideoDetails(context, ref, item)),
      );
    }

    if (layout == LibraryLayout.grid) {
      return GridView.builder(
        key: const Key('library-videos'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: items.length,
        itemBuilder: tile,
      );
    }
    return ListView.builder(
      key: const Key('library-videos'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: tile,
    );
  }
}

class _VideoTile extends StatelessWidget {
  const new({
    required this.item,
    required this.grid,
    required this.isNew,
    required this.onTap,
    required this.onDetails,
    this.progress,
    super.key,
  });

  final LibraryItem item;
  final bool grid;
  final bool isNew;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final resolution = resolutionLabel(item.width, item.height);
    final meta = [
      ?resolution,
      formatBytes(item.size),
      formatDate(item.added, Localizations.localeOf(context).toString()),
    ].join(' · ');
    final thumb = LibraryThumbnail(
      path: item.thumbnailPath,
      icon: Icons.movie_outlined,
      duration: item.durationMs == null
          ? null
          : Duration(milliseconds: item.durationMs!),
      progress: progress,
      badge: isNew ? context.l10n.libraryNew : null,
    );
    final title = Text(
      item.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    final details = Text(
      meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: KyndrelColors.textSecondary),
    );
    return InkWell(
      onTap: onTap,
      onLongPress: onDetails,
      onSecondaryTap: onDetails,
      borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
      child: grid
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: thumb),
                const SizedBox(height: 6),
                title,
                details,
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 128, height: 72, child: thumb),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
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
    );
  }
}

String _resolution(LibraryItem item) {
  final label = resolutionLabel(item.width, item.height);
  return '${item.width} × ${item.height}${label == null ? '' : ' ($label)'}';
}

/// The details of a video, with Play / Add to queue / Show in folder.
Future<void> showVideoDetails(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  final watched = ref.read(watchProgressProvider).value?[item.uri];
  final rows = <(String, String)>[
    (l.detailFolder, item.folderPath),
    if (item.durationMs != null)
      (
        l.detailLength,
        formatDuration(Duration(milliseconds: item.durationMs!)),
      ),
    if (item.width != null && item.height != null)
      (l.detailResolution, _resolution(item)),
    if (item.videoCodec != null) (l.detailVideo, item.videoCodec!),
    if (item.audioCodec != null) (l.detailAudio, item.audioCodec!),
    (l.detailSize, formatBytes(item.size)),
    (l.detailModified, formatDate(item.modified, locale)),
    (l.detailAdded, formatDate(item.added, locale)),
    if (watched?.progress != null)
      (l.detailWatched, '${(watched!.progress! * 100).round()} %'),
  ];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: KyndrelColors.panel,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        key: const Key('video-details'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(label, style: KyndrelTheme.sectionLabel),
                    ),
                    Expanded(child: SelectableText(value)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('details-play'),
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(
                      ref.read(playlistProvider.notifier).open(item.uri),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l.libraryPlay),
                ),
                OutlinedButton.icon(
                  key: const Key('details-enqueue'),
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(
                      ref.read(playlistProvider.notifier).enqueue([item.uri]),
                    );
                  },
                  icon: const Icon(Icons.queue),
                  label: Text(l.libraryEnqueue),
                ),
                if (ref.read(platformCapabilitiesProvider).isDesktop)
                  OutlinedButton.icon(
                    onPressed: () => unawaited(openWithSystem(item.folderPath)),
                    icon: const Icon(Icons.folder_open),
                    label: Text(l.libraryOpenFolder),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Desktop: the folders the library looks in.
Future<void> showLibraryFolders(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _LibraryFoldersDialog(),
);

class _LibraryFoldersDialog extends ConsumerWidget {
  const new();

  Future<void> _add(WidgetRef ref) async {
    final path = await getDirectoryPath();
    if (path == null) return;
    final bookmark = await FolderAccess.bookmark(path);
    updateSettings(
      ref,
      (s) => s.copyWith(
        libraryFolders: [...s.libraryFolders, path],
        // Kept in step with the folders ('' where none is needed).
        libraryBookmarks: [...s.libraryBookmarks, bookmark ?? ''],
      ),
    );
    unawaited(ref.read(mediaIndexProvider).refresh());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final folders = ref.watch(settingsProvider.select((s) => s.libraryFolders));
    return AlertDialog(
      key: const Key('library-folders-dialog'),
      title: Text(l.libraryManageFolders),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (folders.isEmpty) ...[
              Text(
                l.libraryDefaultFolders,
                style: const TextStyle(color: KyndrelColors.textSecondary),
              ),
              for (final f in FolderMediaScanner.defaultFolders())
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f),
                ),
            ],
            for (final f in folders)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder),
                title: Text(f),
                trailing: IconButton(
                  tooltip: l.libraryRemoveFolder,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    final i = folders.indexOf(f);
                    updateSettings(ref, (s) {
                      final paths = [...s.libraryFolders]..removeAt(i);
                      final marks = [...s.libraryBookmarks];
                      if (i < marks.length) marks.removeAt(i);
                      return s.copyWith(
                        libraryFolders: paths,
                        libraryBookmarks: marks,
                      );
                    });
                    unawaited(ref.read(mediaIndexProvider).refresh());
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('library-add-folder'),
          onPressed: () => unawaited(_add(ref)),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(l.libraryAddFolder),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
