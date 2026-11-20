import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The music library's views (task 7.5).
enum MusicView { songs, albums, artists, folders }

/// A group of songs: an album, an artist or a folder.
@immutable
class SongGroup {
  const new(this.key, this.title, this.subtitle, this.songs);

  final String key;
  final String title;
  final String? subtitle;

  /// In play order.
  final List<LibraryItem> songs;

  String? get cover =>
      songs.map((s) => s.thumbnailPath).whereType<String>().firstOrNull;
}

/// What the music library shows.
@immutable
class MusicLibraryView {
  const new({this.view = MusicView.songs, this.group, this.query = ''});

  final MusicView view;

  /// The open album, artist or folder; null shows the list.
  final String? group;
  final String query;

  MusicLibraryView copyWith({
    MusicView? view,
    String? Function()? group,
    String? query,
  }) => MusicLibraryView(
    view: view ?? this.view,
    group: group != null ? group() : this.group,
    query: query ?? this.query,
  );
}

class MusicLibraryController extends Notifier<MusicLibraryView> {
  @override
  MusicLibraryView build() => const MusicLibraryView();

  void show(MusicView view) =>
      state = state.copyWith(view: view, group: () => null);

  void open(String group) => state = state.copyWith(group: () => group);

  void back() => state = state.copyWith(group: () => null);

  void search(String query) => state = state.copyWith(query: query);
}

final musicLibraryProvider =
    NotifierProvider<MusicLibraryController, MusicLibraryView>(
      MusicLibraryController.new,
    );

/// A song's title: its tag, or the file name without the extension.
String songTitle(LibraryItem s) =>
    s.title ?? p.basenameWithoutExtension(s.name);

/// Songs by title.
List<LibraryItem> sortSongs(List<LibraryItem> songs) =>
    [...songs]..sort((a, b) => compareNatural(songTitle(a), songTitle(b)));

/// Album order: track number, then title.
List<LibraryItem> albumOrder(List<LibraryItem> songs) =>
    [...songs]..sort(_byTrack);

int _byTrack(LibraryItem a, LibraryItem b) {
  final t = (a.trackNo ?? 1 << 20).compareTo(b.trackNo ?? 1 << 20);
  return t != 0 ? t : compareNatural(songTitle(a), songTitle(b));
}

int _byAlbumThenTrack(LibraryItem a, LibraryItem b) {
  final album = compareNatural(a.album ?? '', b.album ?? '');
  return album != 0 ? album : _byTrack(a, b);
}

/// Albums, artists or folders, alphabetically; songs without the tag go
/// under "Unknown".
List<SongGroup> groupSongs(
  List<LibraryItem> songs,
  MusicView view, {
  required String unknownAlbum,
  required String unknownArtist,
}) {
  final groups = <String, List<LibraryItem>>{};
  for (final s in songs) {
    final key = switch (view) {
      MusicView.albums => s.album ?? '',
      MusicView.artists => s.artist ?? '',
      MusicView.folders => s.folderPath,
      MusicView.songs => '',
    };
    (groups[key] ??= []).add(s);
  }
  final out = [
    for (final e in groups.entries)
      switch (view) {
        MusicView.albums => SongGroup(
          e.key,
          e.key.isEmpty ? unknownAlbum : e.key,
          _mostCommon(e.value.map((s) => s.artist)) ?? unknownArtist,
          albumOrder(e.value),
        ),
        MusicView.artists => SongGroup(
          e.key,
          e.key.isEmpty ? unknownArtist : e.key,
          null,
          [...e.value]..sort(_byAlbumThenTrack),
        ),
        _ => SongGroup(e.key, e.value.first.folder, e.key, sortSongs(e.value)),
      },
  ]..sort((a, b) => compareNatural(a.title, b.title));
  return out;
}

String? _mostCommon(Iterable<String?> values) {
  final counts = <String, int>{};
  for (final v in values.whereType<String>()) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// Plays [songs] from [start], or shuffled.
Future<void> playSongs(
  WidgetRef ref,
  List<LibraryItem> songs, {
  int start = 0,
  bool shuffle = false,
}) {
  final list = [for (final s in songs) s.uri];
  if (shuffle) list.shuffle(math.Random());
  return ref
      .read(playlistProvider.notifier)
      .openAll(list, start: shuffle ? 0 : start);
}

/// The Music tab: songs, albums, artists and folders of the device's
/// music, separate from the videos (task 7.5).
class MusicLibrary extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryAutoScanProvider);
    final l = context.l10n;
    final view = ref.watch(musicLibraryProvider);
    final controller = ref.read(musicLibraryProvider.notifier);
    final songs =
        ref.watch(libraryItemsProvider(MediaKind.audio)).value ?? const [];
    final status =
        ref.watch(mediaIndexStatusProvider).value ?? const MediaIndexStatus();
    final query = view.query.trim().toLowerCase();

    SongGroup? open;
    var groups = const <SongGroup>[];
    if (view.view != MusicView.songs) {
      groups = groupSongs(
        songs,
        view.view,
        unknownAlbum: l.unknownAlbum,
        unknownArtist: l.unknownArtist,
      );
      if (view.group != null) {
        open = groups.where((g) => g.key == view.group).firstOrNull;
      }
    }

    Widget body;
    if (!status.granted) {
      body = LibraryMessage(
        key: const Key('library-allow'),
        icon: Icons.library_music_outlined,
        text: l.libraryAllowTitle,
        action: FilledButton(
          onPressed: () =>
              unawaited(ref.read(mediaIndexProvider).refresh(ask: true)),
          child: Text(l.libraryAllow),
        ),
      );
    } else if (songs.isEmpty) {
      body = LibraryMessage(
        key: const Key('music-empty'),
        icon: Icons.library_music_outlined,
        text: status.scanning ? l.libraryScanning : l.libraryEmptyMusic,
        busy: status.scanning,
        action: Platform.isAndroid
            ? null
            : OutlinedButton.icon(
                onPressed: () => unawaited(showLibraryFolders(context)),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(l.libraryManageFolders),
              ),
      );
    } else if (query.isNotEmpty) {
      final found = sortSongs([
        for (final s in songs)
          if ('${songTitle(s)} ${s.artist ?? ''} ${s.album ?? ''}'
              .toLowerCase()
              .contains(query))
            s,
      ]);
      body = found.isEmpty
          ? LibraryMessage(icon: Icons.search_off, text: l.libraryNoMatch)
          : _SongList(songs: found);
    } else if (open != null) {
      body = _SongList(
        songs: open.songs,
        header: _GroupHeader(group: open),
      );
    } else if (view.view == MusicView.songs) {
      body = _SongList(songs: sortSongs(songs));
    } else {
      body = _GroupGrid(groups: groups, round: view.view == MusicView.artists);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MusicHeader(
          title: open?.title ?? l.libraryMusic,
          onBack: open == null ? null : controller.back,
          songs: songs,
          scanning: status.scanning || status.toProbe > 0,
        ),
        if (open == null && songs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (v, label) in [
                  (MusicView.songs, l.musicSongs),
                  (MusicView.albums, l.musicAlbums),
                  (MusicView.artists, l.musicArtists),
                  (MusicView.folders, l.libraryFolders),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: Key('music-${v.name}'),
                      label: Text(label),
                      selected: view.view == v,
                      selectedColor: KyndrelColors.rowActive,
                      checkmarkColor: KyndrelColors.accent,
                      labelStyle: TextStyle(
                        color: view.view == v
                            ? KyndrelColors.accent
                            : KyndrelColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => controller.show(v),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
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

class _MusicHeader extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.songs,
    required this.scanning,
    this.onBack,
  });

  final String title;
  final List<LibraryItem> songs;
  final bool scanning;
  final VoidCallback? onBack;

  @override
  ConsumerState<_MusicHeader> createState() => _MusicHeaderState();
}

class _MusicHeaderState extends ConsumerState<_MusicHeader> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = ref.read(musicLibraryProvider.notifier);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              key: const Key('music-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: widget.onBack,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: _searching
                ? TextField(
                    key: const Key('music-search-field'),
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l.librarySearch,
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: c.search,
                  )
                : Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
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
            key: const Key('music-search'),
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
          if (widget.songs.isNotEmpty)
            IconButton(
              key: const Key('music-shuffle'),
              tooltip: l.musicShuffle,
              icon: const Icon(Icons.shuffle),
              onPressed: () =>
                  unawaited(playSongs(ref, widget.songs, shuffle: true)),
            ),
          if (!Platform.isAndroid)
            IconButton(
              key: const Key('music-library-folders'),
              tooltip: l.libraryManageFolders,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: () => unawaited(showLibraryFolders(context)),
            ),
        ],
      ),
    );
  }
}

/// A square cover, or a music note when there is none.
class _Cover extends StatelessWidget {
  const new({required this.path, this.size, this.round = false});

  final String? path;
  final double? size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final cover = path;
    final child = cover == null
        ? const ColoredBox(
            color: KyndrelColors.surface,
            child: Center(
              child: Icon(Icons.music_note, color: KyndrelColors.textSecondary),
            ),
          )
        : Image.file(
            File(cover),
            fit: BoxFit.cover,
            cacheWidth: 320,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: KyndrelColors.surface,
              child: Icon(Icons.music_note),
            ),
          );
    return SizedBox.square(
      dimension: size,
      child: round
          ? ClipOval(child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
              child: child,
            ),
    );
  }
}

class _SongList extends ConsumerWidget {
  const new({required this.songs, this.header});

  final List<LibraryItem> songs;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = header == null ? 0 : 1;
    return ListView.builder(
      key: const Key('music-songs'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: songs.length + extra,
      itemBuilder: (context, i) {
        if (i < extra) return header!;
        final song = songs[i - extra];
        final subtitle = [?song.artist, ?song.album].join(' · ');
        return ListTile(
          key: Key('song-${song.name}'),
          leading: _Cover(path: song.thumbnailPath, size: 44),
          title: Text(
            songTitle(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KyndrelColors.textSecondary),
                ),
          trailing: song.durationMs == null
              ? null
              : Text(
                  formatDuration(Duration(milliseconds: song.durationMs!)),
                  style: const TextStyle(
                    color: KyndrelColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
          onTap: () => unawaited(playSongs(ref, songs, start: i - extra)),
        );
      },
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  const new({required this.group});

  final SongGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _Cover(path: group.cover, size: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group.subtitle != null)
                  Text(
                    group.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KyndrelColors.textSecondary),
                  ),
                Text(
                  l.songCount(group.songs.length),
                  style: const TextStyle(
                    fontSize: 12,
                    color: KyndrelColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('group-play'),
                      onPressed: () => unawaited(playSongs(ref, group.songs)),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.musicPlayAll),
                    ),
                    OutlinedButton.icon(
                      key: const Key('group-shuffle'),
                      onPressed: () =>
                          unawaited(playSongs(ref, group.songs, shuffle: true)),
                      icon: const Icon(Icons.shuffle),
                      label: Text(l.musicShuffle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupGrid extends ConsumerWidget {
  const new({required this.groups, required this.round});

  final List<SongGroup> groups;

  /// Artists: round pictures.
  final bool round;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
    key: const Key('music-groups'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 180,
      mainAxisSpacing: 16,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
    ),
    itemCount: groups.length,
    itemBuilder: (context, i) {
      final g = groups[i];
      return InkWell(
        key: Key('group-${g.title}'),
        borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
        onTap: () => ref.read(musicLibraryProvider.notifier).open(g.key),
        child: Column(
          crossAxisAlignment: round
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _Cover(path: g.cover, round: round),
            ),
            const SizedBox(height: 6),
            Text(
              g.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              g.subtitle != null && !round
                  ? g.subtitle!
                  : context.l10n.songCount(g.songs.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
