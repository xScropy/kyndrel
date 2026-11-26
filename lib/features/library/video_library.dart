import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/platform/folder_access.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/storage/library_watcher.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/core/utils/media_format.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/library/library_actions.dart';
import 'package:kyndrel/features/library/library_lists.dart';
import 'package:kyndrel/features/library/library_playlists.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

export 'package:kyndrel/core/storage/library_repository.dart'
    show LibraryFilter, LibrarySort;

/// The top-level views of the Videos tab (task 8.6).
enum LibraryMode { folders, all, recent, playlists }

enum LibraryLayout { list, grid, compact }

/// Tile size of the grid layout.
enum GridSize {
  small(160),
  medium(240),
  large(320);

  new(this.extent);

  /// Most width of one tile.
  final double extent;
}

/// What the video library shows (tasks 7.4, 8.6).
@immutable
class VideoLibraryView {
  const new({
    this.mode = LibraryMode.folders,
    this.folder,
    this.playlist,
    this.sort = LibrarySort.date,
    this.descending = true,
    this.layout = LibraryLayout.list,
    this.gridSize = GridSize.medium,
    this.filter = const LibraryFilter(),
    this.selection = const {},
    this.showHidden = false,
    this.unlocked = false,
    this.rootSort = LibrarySort.date,
    this.rootDescending = true,
    this.rootLayout = LibraryLayout.list,
  });

  /// The order and layout chosen outside any folder: folders without their
  /// own choice use them.
  final LibrarySort rootSort;
  final bool rootDescending;
  final LibraryLayout rootLayout;

  final LibraryMode mode;

  /// The open folder's path; null shows the folders.
  final String? folder;

  /// The open saved playlist (or a smart one, negative ids).
  final int? playlist;
  final LibrarySort sort;
  final bool descending;
  final LibraryLayout layout;
  final GridSize gridSize;
  final LibraryFilter filter;

  /// Selected files (long-press); empty when not selecting.
  final Set<String> selection;

  /// Hidden folders are listed (dimmed).
  final bool showHidden;

  /// Private folders are open for this session.
  final bool unlocked;

  String get query => filter.query;
  bool get selecting => selection.isNotEmpty;

  VideoLibraryView copyWith({
    LibraryMode? mode,
    String? Function()? folder,
    int? Function()? playlist,
    LibrarySort? sort,
    bool? descending,
    LibraryLayout? layout,
    GridSize? gridSize,
    LibraryFilter? filter,
    Set<String>? selection,
    bool? showHidden,
    bool? unlocked,
    LibrarySort? rootSort,
    bool? rootDescending,
    LibraryLayout? rootLayout,
  }) => VideoLibraryView(
    mode: mode ?? this.mode,
    folder: folder != null ? folder() : this.folder,
    playlist: playlist != null ? playlist() : this.playlist,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
    layout: layout ?? this.layout,
    gridSize: gridSize ?? this.gridSize,
    filter: filter ?? this.filter,
    selection: selection ?? this.selection,
    showHidden: showHidden ?? this.showHidden,
    unlocked: unlocked ?? this.unlocked,
    rootSort: rootSort ?? this.rootSort,
    rootDescending: rootDescending ?? this.rootDescending,
    rootLayout: rootLayout ?? this.rootLayout,
  );
}

class VideoLibraryController extends Notifier<VideoLibraryView> {
  @override
  VideoLibraryView build() => const VideoLibraryView();

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  void show(LibraryMode mode) => state = state.copyWith(
    mode: mode,
    folder: () => null,
    playlist: () => null,
    selection: const {},
  );

  /// Opens [path] with the sort and layout it was left with.
  void openFolder(String path, {LibraryFolder? prefs}) {
    state = state.copyWith(
      folder: () => path,
      selection: const {},
      sort:
          LibrarySort.values.where((s) => s.name == prefs?.sort).firstOrNull ??
          state.rootSort,
      descending: prefs?.descending ?? state.rootDescending,
      layout:
          LibraryLayout.values
              .where((l) => l.name == prefs?.layout)
              .firstOrNull ??
          state.rootLayout,
    );
  }

  void openPlaylist(int id) =>
      state = state.copyWith(playlist: () => id, selection: const {});

  void back() => state = state.copyWith(
    folder: () => null,
    playlist: () => null,
    selection: const {},
    sort: state.rootSort,
    descending: state.rootDescending,
    layout: state.rootLayout,
  );

  void sortBy(LibrarySort sort) {
    // Picking the same order again flips its direction; names start at A,
    // the others with the newest, largest or longest.
    final descending = state.sort == sort
        ? !state.descending
        : sort != LibrarySort.name;
    state = state.copyWith(sort: sort, descending: descending);
    _remember();
  }

  void setDescending({required bool value}) {
    state = state.copyWith(descending: value);
    _remember();
  }

  void setLayout(LibraryLayout layout) {
    state = state.copyWith(layout: layout);
    _remember();
  }

  void setGridSize(GridSize size) => state = state.copyWith(gridSize: size);

  /// Each folder keeps its own order and layout, like MX Player; outside
  /// a folder the choice is the default for folders without their own.
  void _remember() {
    final folder = state.folder;
    if (folder == null) {
      state = state.copyWith(
        rootSort: state.sort,
        rootDescending: state.descending,
        rootLayout: state.layout,
      );
      return;
    }
    unawaited(
      _repo.setFolder(
        folder,
        sort: () => state.sort.name,
        descending: () => state.descending,
        layout: () => state.layout.name,
      ),
    );
  }

  void search(String query) =>
      state = state.copyWith(filter: state.filter.copyWith(query: query));

  void setFilter(LibraryFilter filter) =>
      state = state.copyWith(filter: filter);

  /// Kept for older callers: the "all videos" view.
  void showAll({required bool value}) =>
      show(value ? LibraryMode.all : LibraryMode.folders);

  void toggleSelected(String uri) {
    final s = {...state.selection};
    if (!s.remove(uri)) s.add(uri);
    state = state.copyWith(selection: s);
  }

  void selectAll(Iterable<String> uris) =>
      state = state.copyWith(selection: {...uris});

  void clearSelection() => state = state.copyWith(selection: const {});

  void showHidden({required bool value}) =>
      state = state.copyWith(showHidden: value);

  void setUnlocked({required bool value}) =>
      state = state.copyWith(unlocked: value);
}

final videoLibraryProvider =
    NotifierProvider<VideoLibraryController, VideoLibraryView>(
      VideoLibraryController.new,
    );

/// Video folders with their numbers (SQL, task 8.5).
final libraryFoldersProvider = StreamProvider<List<FolderSummary>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchFolders(MediaKind.video),
);

/// The user's choices per folder.
final libraryFolderPrefsProvider = StreamProvider<Map<String, LibraryFolder>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchFolderPrefs(),
);

/// One list of videos: a folder, or all of them; sorted and filtered.
typedef LibraryQuery = ({
  String? folder,
  LibrarySort sort,
  bool descending,
  LibraryFilter filter,
});

final StreamProviderFamily<List<LibraryItem>, LibraryQuery>
libraryListProvider = StreamProvider.family<List<LibraryItem>, LibraryQuery>(
  (ref, q) => ref
      .watch(libraryRepositoryProvider)
      .watchItems(
        MediaKind.video,
        folder: q.folder,
        sort: q.sort,
        descending: q.descending,
        filter: q.filter,
      ),
);

/// "NEW": added in the last week and never played.
bool isNewItem(
  LibraryItem item,
  Map<String, HistoryItem> progress,
  DateTime now,
) =>
    !progress.containsKey(item.uri) &&
    now.difference(item.added) < const Duration(days: 7);

/// Played to the end, or marked watched.
bool isWatched(LibraryItem item, Map<String, HistoryItem> progress) =>
    item.watched || (progress[item.uri]?.finished ?? false);

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

/// Videos added in the last month count as "recently added".
const recentWindow = Duration(days: 30);

/// The Videos tab, like MX Player (tasks 7.4, 8.6): folders, all videos,
/// recently added and playlists; list, grid or compact; a fast-scroller,
/// scene previews on the thumbnails, multi-select with file actions.
class VideoLibrary extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryAutoScanProvider);
    final view = ref.watch(videoLibraryProvider);
    final status =
        ref.watch(mediaIndexStatusProvider).value ?? const MediaIndexStatus();
    final progress = ref.watch(watchProgressProvider).value ?? const {};
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final prefs = ref.watch(libraryFolderPrefsProvider).value ?? const {};
    final controller = ref.read(videoLibraryProvider.notifier);
    final l = context.l10n;

    /// Hidden and locked private folders stay out of every list.
    bool visible(String folderPath) {
      final p = prefs[folderPath];
      if (p == null) return true;
      if (p.private && !view.unlocked) return false;
      if (p.hidden && !view.showHidden) return false;
      return true;
    }

    final openFolder = view.folder == null
        ? null
        : folders.where((f) => f.path == view.folder).firstOrNull;
    final searching = view.query.trim().isNotEmpty;
    final listing =
        openFolder != null ||
        searching ||
        view.mode == LibraryMode.all ||
        view.mode == LibraryMode.recent;
    final items = listing
        ? (ref
                  .watch(
                    libraryListProvider((
                      folder: openFolder?.path,
                      sort: view.mode == LibraryMode.recent && !searching
                          ? LibrarySort.date
                          : view.sort,
                      descending:
                          view.mode == LibraryMode.recent && !searching ||
                          view.descending,
                      filter: view.filter,
                    )),
                  )
                  .value ??
              const <LibraryItem>[])
        : const <LibraryItem>[];
    final now = clock.now();
    final shown = [
      for (final i in items)
        if ((openFolder != null || visible(i.folderPath)) &&
            (!view.filter.unwatched || !isWatched(i, progress)) &&
            (view.mode != LibraryMode.recent ||
                searching ||
                openFolder != null ||
                now.difference(i.added) < recentWindow))
          i,
    ];

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
    } else if (view.mode == LibraryMode.playlists && !searching) {
      body = view.playlist == null
          ? const PlaylistsView()
          : PlaylistView(id: view.playlist!);
    } else if (folders.isEmpty) {
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
    } else if (listing) {
      body = shown.isEmpty
          ? LibraryMessage(icon: Icons.search_off, text: l.libraryNoMatch)
          : VideoList(
              key: PageStorageKey(
                'library-${openFolder?.path ?? view.mode.name}',
              ),
              items: shown,
              view: view,
              progress: progress,
            );
    } else {
      body = FolderGrid(
        key: const PageStorageKey('library-folders'),
        folders: [
          for (final f in folders)
            if (visible(f.path)) f,
        ],
        progress: progress,
      );
    }

    final inPlaylist =
        view.mode == LibraryMode.playlists && view.playlist != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.selecting)
          SelectionBar(all: shown)
        else
          _Header(
            title: openFolder?.name ?? l.libraryVideos,
            subtitle: openFolder == null
                ? null
                : l.videoCount(openFolder.count),
            onBack: openFolder != null || inPlaylist ? controller.back : null,
            view: view,
            scanning: status.scanning || status.toProbe > 0,
            folder: openFolder,
            playable: shown,
          ),
        if (openFolder == null && !inPlaylist && !view.selecting)
          _ModeChips(mode: view.mode),
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

/// Folders · All videos · Recently added · Playlists.
class _ModeChips extends ConsumerWidget {
  const new({required this.mode});

  final LibraryMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(videoLibraryProvider.notifier);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (m, label, icon) in [
            (LibraryMode.folders, l.libraryFolders, Icons.folder_outlined),
            (LibraryMode.all, l.libraryAllVideos, Icons.video_library_outlined),
            (LibraryMode.recent, l.libraryViewRecent, Icons.schedule),
            (
              LibraryMode.playlists,
              l.libraryViewPlaylists,
              Icons.playlist_play,
            ),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: Key('library-view-${m.name}'),
                avatar: Icon(
                  icon,
                  size: 18,
                  color: mode == m
                      ? KyndrelColors.accent
                      : KyndrelColors.textSecondary,
                ),
                label: Text(label),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: mode == m
                      ? KyndrelColors.accent
                      : KyndrelColors.textPrimary,
                ),
                selected: mode == m,
                showCheckmark: false,
                selectedColor: KyndrelColors.rowActive,
                backgroundColor: KyndrelColors.background,
                side: BorderSide(
                  color: mode == m
                      ? KyndrelColors.accent
                      : KyndrelColors.panelBorder,
                ),
                onSelected: (_) => c.show(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.view,
    required this.scanning,
    required this.playable,
    this.subtitle,
    this.onBack,
    this.folder,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VideoLibraryView view;
  final bool scanning;
  final FolderSummary? folder;

  /// What "Play all" and "Shuffle" play.
  final List<LibraryItem> playable;

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
    final folder = widget.folder;
    final f = view.filter;
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
          if (folder != null)
            IconButton(
              key: const Key('library-folder-actions'),
              tooltip: l.libraryFolderActions,
              icon: const Icon(Icons.more_vert),
              onPressed: () => unawaited(
                showFolderActions(context, ref, folder, widget.playable),
              ),
            ),
          PopupMenuButton<Object>(
            key: const Key('library-menu'),
            tooltip: l.librarySort,
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              switch (v) {
                case final LibrarySort s:
                  c.sortBy(s);
                case final LibraryLayout layout:
                  c.setLayout(layout);
                case final GridSize size:
                  c.setGridSize(size);
                case 'descending':
                  c.setDescending(value: !view.descending);
                case 'unwatched':
                  c.setFilter(f.copyWith(unwatched: !f.unwatched));
                case 'hd':
                  c.setFilter(f.copyWith(hd: !f.hd));
                case 'subtitles':
                  c.setFilter(f.copyWith(subtitles: !f.subtitles));
                case 'hidden':
                  c.showHidden(value: !view.showHidden);
                case 'private':
                  unawaited(togglePrivateFolders(context, ref));
                case 'folders':
                  unawaited(showLibraryFolders(context));
              }
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
              CheckedPopupMenuItem(
                key: const Key('sort-descending'),
                value: 'descending',
                checked: view.descending,
                child: Text(l.libraryDescending),
              ),
              const PopupMenuDivider(),
              for (final (layout, label) in [
                (LibraryLayout.list, l.layoutList),
                (LibraryLayout.grid, l.layoutGrid),
                (LibraryLayout.compact, l.layoutCompact),
              ])
                CheckedPopupMenuItem(
                  key: Key('layout-${layout.name}'),
                  value: layout,
                  checked: view.layout == layout,
                  child: Text(label),
                ),
              if (view.layout == LibraryLayout.grid)
                for (final (size, label) in [
                  (GridSize.small, l.libraryGridSmall),
                  (GridSize.large, l.libraryGridLarge),
                ])
                  CheckedPopupMenuItem(
                    key: Key('grid-${size.name}'),
                    value: view.gridSize == size ? GridSize.medium : size,
                    checked: view.gridSize == size,
                    child: Text(label),
                  ),
              const PopupMenuDivider(),
              for (final (key, label, on) in [
                ('unwatched', l.libraryFilterUnwatched, f.unwatched),
                ('hd', l.libraryFilterHd, f.hd),
                ('subtitles', l.libraryFilterSubtitles, f.subtitles),
              ])
                CheckedPopupMenuItem(
                  key: Key('filter-$key'),
                  value: key,
                  checked: on,
                  child: Text(label),
                ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                key: const Key('library-show-hidden'),
                value: 'hidden',
                checked: view.showHidden,
                child: Text(l.libraryShowHidden),
              ),
              CheckedPopupMenuItem(
                key: const Key('library-private'),
                value: 'private',
                checked: view.unlocked,
                child: Text(view.unlocked ? l.libraryLock : l.libraryPrivate),
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
