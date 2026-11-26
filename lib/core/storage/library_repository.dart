import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';

/// How a library list is ordered.
enum LibrarySort { date, name, size, length }

/// Narrows a library list (task 8.5).
@immutable
class LibraryFilter {
  const new({
    this.unwatched = false,
    this.hd = false,
    this.subtitles = false,
    this.query = '',
  });

  /// Not marked watched and never played to the end.
  final bool unwatched;

  /// 1080p or more.
  final bool hd;

  /// With a subtitle file beside it.
  final bool subtitles;

  /// Part of the file name, any case.
  final String query;

  bool get isEmpty => !unwatched && !hd && !subtitles && query.isEmpty;

  LibraryFilter copyWith({
    bool? unwatched,
    bool? hd,
    bool? subtitles,
    String? query,
  }) => LibraryFilter(
    unwatched: unwatched ?? this.unwatched,
    hd: hd ?? this.hd,
    subtitles: subtitles ?? this.subtitles,
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.unwatched == unwatched &&
      other.hd == hd &&
      other.subtitles == subtitles &&
      other.query == query;

  @override
  int get hashCode => Object.hash(unwatched, hd, subtitles, query);
}

/// A folder of the library with its numbers, grouped by SQL (task 8.5).
@immutable
class FolderSummary {
  const new({
    required this.path,
    required this.name,
    required this.count,
    required this.bytes,
    required this.newest,
    this.cover,
    this.prefs,
  });

  final String path;
  final String name;
  final int count;
  final int bytes;

  /// When its newest file was added.
  final DateTime newest;

  /// The newest file's thumbnail.
  final String? cover;

  /// The user's choices for it; null when none were made.
  final LibraryFolder? prefs;

  bool get pinned => prefs?.pinned ?? false;
  bool get hidden => prefs?.hidden ?? false;
  bool get private => prefs?.private ?? false;
}

/// Library choices: folders, watched marks and saved playlists (task 8.5).
class LibraryRepository {
  new(this.db);

  final KyndrelDatabase db;

  // ------------------------------------------------------------- folders

  /// Folders holding [kind] files with their counts, pinned first, then the
  /// most recently added.
  Stream<List<FolderSummary>> watchFolders(MediaKind kind) {
    final query = db.customSelect(
      '''
      SELECT i.folder_path AS path, MAX(i.folder) AS name,
        COUNT(*) AS n, SUM(i.size) AS bytes, MAX(i.added) AS newest,
        (SELECT c.thumbnail_path FROM library_items c
          WHERE c.folder_path = i.folder_path AND c.kind = ?1
            AND c.thumbnail_path IS NOT NULL
          ORDER BY c.added DESC LIMIT 1) AS cover,
        f.path AS f_path, f.hidden AS f_hidden, f.pinned AS f_pinned,
        f.private AS f_private, f.sort AS f_sort,
        f.descending AS f_descending, f.layout AS f_layout
      FROM library_items i
      LEFT JOIN library_folders f ON f.path = i.folder_path
      WHERE i.kind = ?1
      GROUP BY i.folder_path
      ''',
      variables: [Variable.withString(kind.name)],
      readsFrom: {db.libraryItems, db.libraryFolders},
    );
    return query.watch().map((rows) {
      final out =
          [
            for (final r in rows)
              FolderSummary(
                path: r.read<String>('path'),
                name: r.read<String>('name'),
                count: r.read<int>('n'),
                bytes: r.read<int?>('bytes') ?? 0,
                newest: r.read<DateTime>('newest'),
                cover: r.read<String?>('cover'),
                prefs: r.read<String?>('f_path') == null
                    ? null
                    : LibraryFolder(
                        path: r.read<String>('f_path'),
                        hidden: r.read<bool>('f_hidden'),
                        pinned: r.read<bool>('f_pinned'),
                        private: r.read<bool>('f_private'),
                        sort: r.read<String?>('f_sort'),
                        descending: r.read<bool?>('f_descending'),
                        layout: r.read<String?>('f_layout'),
                      ),
              ),
          ]..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return b.newest.compareTo(a.newest);
          });
      return out;
    });
  }

  Stream<Map<String, LibraryFolder>> watchFolderPrefs() => db
      .select(db.libraryFolders)
      .watch()
      .map((rows) => {for (final r in rows) r.path: r});

  /// Changes the choices for [path]; fields left null stay as they are.
  Future<void> setFolder(
    String path, {
    bool? hidden,
    bool? pinned,
    bool? private,
    String? Function()? sort,
    bool? Function()? descending,
    String? Function()? layout,
  }) async {
    final old = await (db.select(
      db.libraryFolders,
    )..where((t) => t.path.equals(path))).getSingleOrNull();
    await db
        .into(db.libraryFolders)
        .insertOnConflictUpdate(
          LibraryFoldersCompanion.insert(
            path: path,
            hidden: Value(hidden ?? old?.hidden ?? false),
            pinned: Value(pinned ?? old?.pinned ?? false),
            private: Value(private ?? old?.private ?? false),
            sort: Value(sort != null ? sort() : old?.sort),
            descending: Value(
              descending != null ? descending() : old?.descending,
            ),
            layout: Value(layout != null ? layout() : old?.layout),
          ),
        );
  }

  // --------------------------------------------------------------- items

  /// [kind] files, in [folder] when given, ordered and filtered in SQL.
  /// Name order is natural ("Ep 2" before "Ep 10"), done after the query.
  /// [finished] lists sources played to the end (history), for
  /// [LibraryFilter.unwatched].
  Stream<List<LibraryItem>> watchItems(
    MediaKind kind, {
    String? folder,
    LibrarySort sort = LibrarySort.date,
    bool descending = true,
    LibraryFilter filter = const LibraryFilter(),
    Set<String> finished = const {},
  }) {
    final q = db.select(db.libraryItems)
      ..where((t) {
        var e = t.kind.equals(kind.name);
        if (folder != null) e = e & t.folderPath.equals(folder);
        if (filter.hd) e = e & t.height.isBiggerOrEqualValue(1080);
        if (filter.subtitles) e = e & t.hasSubtitles.equals(true);
        if (filter.unwatched) e = e & t.watched.equals(false);
        if (filter.query.isNotEmpty) {
          e = e & t.name.lower().contains(filter.query.toLowerCase());
        }
        return e;
      });
    final mode = descending ? OrderingMode.desc : OrderingMode.asc;
    switch (sort) {
      case LibrarySort.date:
        q.orderBy([(t) => OrderingTerm(expression: t.added, mode: mode)]);
      case LibrarySort.size:
        q.orderBy([(t) => OrderingTerm(expression: t.size, mode: mode)]);
      case LibrarySort.length:
        q.orderBy([(t) => OrderingTerm(expression: t.durationMs, mode: mode)]);
      case LibrarySort.name:
        break;
    }
    return q.watch().map((items) {
      var out = items;
      if (filter.unwatched && finished.isNotEmpty) {
        out = [
          for (final i in out)
            if (!finished.contains(i.uri)) i,
        ];
      }
      if (sort == LibrarySort.name) {
        out = [...out]
          ..sort(
            (a, b) => descending
                ? compareNatural(b.name, a.name)
                : compareNatural(a.name, b.name),
          );
      }
      return out;
    });
  }

  /// Marks [uris] watched or not.
  Future<void> setWatched(Iterable<String> uris, {required bool watched}) =>
      (db.update(db.libraryItems)..where((t) => t.uri.isIn(uris))).write(
        LibraryItemsCompanion(watched: Value(watched)),
      );

  /// Forgets [uris] (deleted or moved by the user), before the next scan.
  Future<void> forget(Iterable<String> uris) =>
      (db.delete(db.libraryItems)..where((t) => t.uri.isIn(uris))).go();

  // ----------------------------------------------------------- playlists

  /// Saved playlists with their lengths, newest first.
  Stream<List<(SavedPlaylist, int)>> watchPlaylists() {
    final count = db.savedPlaylistItems.uri.count();
    final q =
        db.select(db.savedPlaylists).join([
            leftOuterJoin(
              db.savedPlaylistItems,
              db.savedPlaylistItems.playlistId.equalsExp(db.savedPlaylists.id),
            ),
          ])
          ..addColumns([count])
          ..groupBy([db.savedPlaylists.id])
          ..orderBy([OrderingTerm.desc(db.savedPlaylists.createdAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          (r.readTable(db.savedPlaylists), r.read(count) ?? 0),
      ],
    );
  }

  /// The files of playlist [id], in order.
  Stream<List<String>> watchPlaylist(int id) =>
      (db.select(db.savedPlaylistItems)
            ..where((t) => t.playlistId.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch()
          .map((rows) => [for (final r in rows) r.uri]);

  Future<int> createPlaylist(String name, [List<String> uris = const []]) =>
      db.transaction(() async {
        final id = await db
            .into(db.savedPlaylists)
            .insert(
              SavedPlaylistsCompanion.insert(
                name: name,
                createdAt: DateTime.now(),
              ),
            );
        await _write(id, uris);
        return id;
      });

  Future<void> renamePlaylist(int id, String name) =>
      (db.update(db.savedPlaylists)..where((t) => t.id.equals(id))).write(
        SavedPlaylistsCompanion(name: Value(name)),
      );

  Future<void> deletePlaylist(int id) => db.transaction(() async {
    await (db.delete(
      db.savedPlaylistItems,
    )..where((t) => t.playlistId.equals(id))).go();
    await (db.delete(db.savedPlaylists)..where((t) => t.id.equals(id))).go();
  });

  /// Adds [uris] at the end of playlist [id] (ones already in it stay put).
  Future<void> addToPlaylist(int id, List<String> uris) =>
      db.transaction(() async {
        final now = await watchPlaylist(id).first;
        await _write(id, [
          ...now,
          for (final u in uris)
            if (!now.contains(u)) u,
        ]);
      });

  /// Replaces playlist [id]'s files (after a reorder or removal).
  Future<void> setPlaylist(int id, List<String> uris) =>
      db.transaction(() => _write(id, uris));

  Future<void> _write(int id, List<String> uris) async {
    await (db.delete(
      db.savedPlaylistItems,
    )..where((t) => t.playlistId.equals(id))).go();
    await db.batch((b) {
      for (final (i, uri) in uris.indexed) {
        b.insert(
          db.savedPlaylistItems,
          SavedPlaylistItemsCompanion.insert(
            playlistId: id,
            position: i,
            uri: uri,
          ),
        );
      }
    });
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(databaseProvider)),
);
