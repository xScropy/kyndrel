import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/media_prober.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/storage/library_watcher.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

/// Task 8.5: the library's data layer.
void main() {
  late KyndrelDatabase db;
  late LibraryRepository repo;
  setUp(() {
    db = testDatabase();
    repo = LibraryRepository(db);
  });
  tearDown(() => db.close());

  Future<void> add(
    String uri, {
    String kind = 'video',
    int day = 1,
    int size = 100,
    int? height,
    bool subtitles = false,
    String? thumb,
    int minutes = 10,
  }) => db
      .into(db.libraryItems)
      .insert(
        LibraryItemsCompanion.insert(
          uri: uri,
          name: p.basename(uri),
          folder: p.basename(p.dirname(uri)),
          folderPath: p.dirname(uri),
          kind: kind,
          size: Value(size),
          modified: DateTime(2026),
          added: DateTime(2026, 1, day),
          height: Value(height),
          hasSubtitles: Value(subtitles),
          thumbnailPath: Value(thumb),
          durationMs: Value(minutes * 60000),
        ),
      );

  test('folders: counts, sizes, newest cover; pinned first', () async {
    await add('/a/x.mkv', size: 10, thumb: '/t/x.jpg');
    await add('/a/y.mkv', day: 3, size: 20, thumb: '/t/y.jpg');
    await add('/b/z.mkv', day: 5, size: 5);
    await add('/a/song.mp3', kind: 'audio', day: 9);
    var folders = await repo.watchFolders(MediaKind.video).first;
    expect(folders.map((f) => f.path), ['/b', '/a']);
    final a = folders[1];
    expect((a.name, a.count, a.bytes), ('a', 2, 30));
    expect(a.cover, '/t/y.jpg');
    expect(a.newest, DateTime(2026, 1, 3));

    await repo.setFolder('/a', pinned: true);
    folders = await repo.watchFolders(MediaKind.video).first;
    expect(folders.map((f) => f.path), ['/a', '/b']);
    expect(folders.first.pinned, isTrue);
    // Other choices are kept when one changes.
    await repo.setFolder('/a', hidden: true, sort: () => 'name');
    folders = await repo.watchFolders(MediaKind.video).first;
    expect(folders.first.pinned, isTrue);
    expect(folders.first.hidden, isTrue);
    expect(folders.first.prefs?.sort, 'name');
  });

  test('items: sorted and filtered in SQL, names in natural order', () async {
    await add('/s/Ep 10.mkv', size: 300, height: 720);
    await add('/s/Ep 2.mkv', day: 2, height: 1080);
    await add('/s/Ep 1.mkv', day: 3, size: 200, height: 2160, subtitles: true);
    await add('/o/Other.mkv', day: 4);
    Future<List<String>> names({
      LibrarySort sort = LibrarySort.date,
      bool descending = true,
      LibraryFilter filter = const LibraryFilter(),
      Set<String> finished = const {},
    }) async => [
      for (final i
          in await repo
              .watchItems(
                MediaKind.video,
                folder: '/s',
                sort: sort,
                descending: descending,
                filter: filter,
                finished: finished,
              )
              .first)
        i.name,
    ];

    expect(await names(), ['Ep 1.mkv', 'Ep 2.mkv', 'Ep 10.mkv']);
    expect(await names(sort: LibrarySort.name, descending: false), [
      'Ep 1.mkv',
      'Ep 2.mkv',
      'Ep 10.mkv',
    ]);
    expect(await names(sort: LibrarySort.size), [
      'Ep 10.mkv',
      'Ep 1.mkv',
      'Ep 2.mkv',
    ]);
    expect(await names(filter: const LibraryFilter(hd: true)), [
      'Ep 1.mkv',
      'Ep 2.mkv',
    ]);
    expect(await names(filter: const LibraryFilter(subtitles: true)), [
      'Ep 1.mkv',
    ]);
    expect(await names(filter: const LibraryFilter(query: 'EP 1')), [
      'Ep 1.mkv',
      'Ep 10.mkv',
    ]);
    await repo.setWatched(['/s/Ep 1.mkv'], watched: true);
    expect(
      await names(
        filter: const LibraryFilter(unwatched: true),
        finished: {'/s/Ep 2.mkv'},
      ),
      ['Ep 10.mkv'],
    );
  });

  test('playlists: create, add, reorder, rename, delete', () async {
    final id = await repo.createPlaylist('Weekend', ['/a.mkv', '/b.mkv']);
    await repo.addToPlaylist(id, ['/b.mkv', '/c.mkv']);
    expect(await repo.watchPlaylist(id).first, ['/a.mkv', '/b.mkv', '/c.mkv']);
    await repo.setPlaylist(id, ['/c.mkv', '/a.mkv']);
    expect(await repo.watchPlaylist(id).first, ['/c.mkv', '/a.mkv']);
    await repo.renamePlaylist(id, 'Sunday');
    final lists = await repo.watchPlaylists().first;
    expect(lists.single.$1.name, 'Sunday');
    expect(lists.single.$2, 2);
    await repo.createPlaylist('Empty');
    expect((await repo.watchPlaylists().first).map((l) => l.$2), [0, 2]);
    await repo.deletePlaylist(id);
    expect((await repo.watchPlaylists().first).map((l) => l.$1.name), [
      'Empty',
    ]);
  });

  group('scanner', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('kyndrel_scan'));
    tearDown(() => root.deleteSync(recursive: true));

    File touch(String rel) => File(p.join(root.path, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    test('.nomedia folders are skipped; subtitles beside videos', () async {
      touch('Films/Heist.mkv');
      touch('Films/Heist.en.srt');
      touch('Films/Arrival.mp4');
      touch('Films/Other.srt');
      touch('Private/secret.mkv');
      touch('Private/.nomedia');
      touch('Private/Deeper/also.mkv');
      final found = await FolderMediaScanner([root.path]).scan();
      expect(found.map((f) => f.name).toSet(), {'Heist.mkv', 'Arrival.mp4'});
      final heist = found.firstWhere((f) => f.name == 'Heist.mkv');
      expect(heist.hasSubtitles, isTrue);
      expect(
        found.firstWhere((f) => f.name == 'Arrival.mp4').hasSubtitles,
        isFalse,
      );
    });

    test('a new subtitle file updates the flag; watched marks stay', () async {
      touch('Films/Heist.mkv');
      final index = MediaIndex(
        db: db,
        scanner: FolderMediaScanner([root.path]),
        prober: _NoProbe(),
      );
      addTearDown(index.dispose);
      await index.refresh();
      final uri = p.join(root.path, 'Films', 'Heist.mkv');
      await repo.setWatched([uri], watched: true);
      touch('Films/Heist.srt');
      await index.refresh();
      final item = await (db.select(
        db.libraryItems,
      )..where((t) => t.uri.equals(uri))).getSingle();
      expect(item.hasSubtitles, isTrue);
      expect(item.watched, isTrue);
    });

    test('the watcher rescans when a video appears', () async {
      touch('Films/Heist.mkv');
      final index = MediaIndex(
        db: db,
        scanner: FolderMediaScanner([root.path]),
        prober: _NoProbe(),
      );
      addTearDown(index.dispose);
      await index.refresh();
      final watcher = LibraryWatcher(
        index: index,
        roots: [root.path],
        folders: () async => [p.join(root.path, 'Films')],
        desktop: true,
        debounce: const Duration(milliseconds: 100),
      );
      addTearDown(watcher.dispose);
      await watcher.start();
      expect(watcher.watching, 2);
      touch('Films/Arrival.mp4');
      // Debounce, then a scan in an isolate.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      var items = <LibraryItem>[];
      while (items.length < 2 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        items = await db.select(db.libraryItems).get();
      }
      expect(items.map((i) => i.name).toSet(), {'Heist.mkv', 'Arrival.mp4'});
    });
  });

  test('a version 3 database gains the Phase 8 tables', () async {
    final v3 = NativeDatabase.memory(
      setup: (raw) {
        raw
          ..execute(
            'CREATE TABLE library_items (uri TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, folder TEXT NOT NULL, '
            'folder_path TEXT NOT NULL, kind TEXT NOT NULL, '
            'size INTEGER NOT NULL DEFAULT 0, modified TEXT NOT NULL, '
            'added TEXT NOT NULL, duration_ms INTEGER, width INTEGER, '
            'height INTEGER, video_codec TEXT, audio_codec TEXT, title TEXT, '
            'artist TEXT, album TEXT, track_no INTEGER, thumbnail_path TEXT, '
            'probed INTEGER NOT NULL DEFAULT 0)',
          )
          ..execute(
            'INSERT INTO library_items (uri, name, folder, folder_path, '
            "kind, modified, added) VALUES ('/a/x.mkv', 'x.mkv', 'a', '/a', "
            "'video', '2026-01-01T00:00:00.000', '2026-01-01T00:00:00.000')",
          )
          ..execute('PRAGMA user_version = 3');
      },
    );
    final upgraded = KyndrelDatabase(DatabaseConnection(v3));
    addTearDown(upgraded.close);
    final item = (await upgraded.select(upgraded.libraryItems).get()).single;
    expect((item.watched, item.hasSubtitles), (false, false));
    final r = LibraryRepository(upgraded);
    await r.createPlaylist('New', ['/a/x.mkv']);
    await r.setFolder('/a', pinned: true);
    expect((await r.watchFolders(MediaKind.video).first).single.pinned, true);
    expect(await upgraded.select(upgraded.bookmarks).get(), isEmpty);
    expect(await upgraded.select(upgraded.introMarks).get(), isEmpty);
  });
}

class _NoProbe implements MediaProber {
  @override
  Future<ProbedDetails?> probe(String uri) async => null;

  @override
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  }) async => null;
}
