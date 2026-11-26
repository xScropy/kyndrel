import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/features/library/library_actions.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Smart playlists have negative ids.
const smartUnwatched = -1;
const smartRecent = -2;

final savedPlaylistsProvider = StreamProvider<List<(SavedPlaylist, int)>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchPlaylists(),
);

final StreamProviderFamily<List<String>, int> _savedPlaylistProvider =
    StreamProvider.family<List<String>, int>(
      (ref, id) => ref.watch(libraryRepositoryProvider).watchPlaylist(id),
    );

/// Every library video, newest first.
final _allVideosProvider = Provider<List<LibraryItem>>(
  (ref) =>
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
      const [],
);

/// Saved playlists, and two that fill themselves (task 8.6).
class PlaylistsView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final saved = ref.watch(savedPlaylistsProvider).value ?? const [];
    final c = ref.read(videoLibraryProvider.notifier);
    final repo = ref.read(libraryRepositoryProvider);
    return ListView(
      key: const Key('library-playlists'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          key: const Key('playlist-smart-unwatched'),
          leading: const Icon(Icons.auto_awesome, color: KyndrelColors.accent),
          title: Text(l.librarySmartUnwatched),
          onTap: () => c.openPlaylist(smartUnwatched),
        ),
        ListTile(
          key: const Key('playlist-smart-recent'),
          leading: const Icon(Icons.auto_awesome, color: KyndrelColors.accent),
          title: Text(l.librarySmartRecent),
          onTap: () => c.openPlaylist(smartRecent),
        ),
        const Divider(),
        if (saved.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l.libraryPlaylistEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KyndrelColors.textSecondary),
            ),
          ),
        for (final (list, count) in saved)
          ListTile(
            key: Key('saved-playlist-${list.name}'),
            leading: const Icon(Icons.playlist_play),
            title: Text(list.name),
            subtitle: Text(l.videoCount(count)),
            onTap: () => c.openPlaylist(list.id),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  await repo.deletePlaylist(list.id);
                } else if (v == 'rename') {
                  final name = await askPlaylistName(context, list.name);
                  if (name != null && name.trim().isNotEmpty) {
                    await repo.renamePlaylist(list.id, name.trim());
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l.playlistRename)),
                PopupMenuItem(value: 'delete', child: Text(l.playlistDelete)),
              ],
            ),
          ),
      ],
    );
  }
}

/// One playlist: play it, reorder it (saved ones), remove from it.
class PlaylistView extends ConsumerWidget {
  const new({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = ref.watch(_allVideosProvider);
    final progress = ref.watch(watchProgressProvider).value ?? const {};
    final now = clock.now();
    final byUri = {for (final i in all) i.uri: i};
    final List<String> uris;
    final String title;
    switch (id) {
      case smartUnwatched:
        title = l.librarySmartUnwatched;
        uris = [
          for (final i in all)
            if (!isWatched(i, progress)) i.uri,
        ];
      case smartRecent:
        title = l.librarySmartRecent;
        uris = [
          for (final i in all)
            if (now.difference(i.added) < recentWindow) i.uri,
        ];
      default:
        final saved = ref.watch(savedPlaylistsProvider).value ?? const [];
        title = saved.where((s) => s.$1.id == id).firstOrNull?.$1.name ?? '';
        uris = ref.watch(_savedPlaylistProvider(id)).value ?? const [];
    }
    final smart = id < 0;
    final repo = ref.read(libraryRepositoryProvider);

    Widget row(int i) {
      final uri = uris[i];
      final item = byUri[uri];
      return ListTile(
        key: ValueKey('playlist-item-$uri'),
        leading: SizedBox(
          width: 96,
          height: 54,
          child: LibraryThumbnail(
            path: item?.thumbnailPath,
            icon: Icons.movie_outlined,
            progress: progress[uri]?.progress,
          ),
        ),
        title: Text(
          item?.name ?? p.basename(uri),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => unawaited(
          ref.read(playlistProvider.notifier).openAll(uris, start: i),
        ),
        trailing: smart
            ? null
            : IconButton(
                tooltip: l.playlistRemove,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () =>
                    unawaited(repo.setPlaylist(id, [...uris]..removeAt(i))),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$title · ${l.videoCount(uris.length)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                key: const Key('playlist-play'),
                onPressed: uris.isEmpty
                    ? null
                    : () => unawaited(
                        ref.read(playlistProvider.notifier).openAll(uris),
                      ),
                icon: const Icon(Icons.play_arrow),
                label: Text(l.libraryPlayAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: smart
              ? ListView.builder(
                  key: const Key('playlist-items'),
                  itemCount: uris.length,
                  itemBuilder: (_, i) => row(i),
                )
              : ReorderableListView.builder(
                  key: const Key('playlist-items'),
                  itemCount: uris.length,
                  onReorderItem: (from, to) {
                    final next = [...uris];
                    final moved = next.removeAt(from);
                    next.insert(to, moved);
                    unawaited(repo.setPlaylist(id, next));
                  },
                  itemBuilder: (_, i) => row(i),
                ),
        ),
      ],
    );
  }
}
