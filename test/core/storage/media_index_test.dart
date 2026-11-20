import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/media_prober.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

class _Scanner implements MediaScanner {
  List<ScannedFile> files = [];
  bool grant = true;
  int scans = 0;

  @override
  Future<bool> requestAccess() async => grant;

  @override
  Future<List<ScannedFile>> scan() async {
    scans++;
    return files;
  }
}

class _Prober implements MediaProber {
  final probed = <String>[];

  @override
  Future<ProbedDetails?> probe(String uri) async {
    probed.add(uri);
    return ProbedDetails(
      duration: const Duration(minutes: 3),
      width: uri.endsWith('.mkv') ? 1920 : null,
      height: uri.endsWith('.mkv') ? 1080 : null,
      videoCodec: uri.endsWith('.mkv') ? 'h264' : null,
      title: uri.endsWith('.mp3') ? 'Song' : null,
      hasCover: true,
    );
  }

  @override
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  }) async => '/thumbs/${p.basename(uri)}.jpg';
}

ScannedFile _file(String path, {int size = 100, DateTime? modified}) =>
    ScannedFile(
      uri: path,
      name: p.basename(path),
      folderPath: p.dirname(path),
      kind: FolderMediaScanner.kindOf(path)!,
      size: size,
      modified: modified ?? DateTime(2026),
    );

/// Task 7.3: the media index.
void main() {
  late KyndrelDatabase db;
  late _Scanner scanner;
  late _Prober prober;
  late MediaIndex index;
  var now = DateTime(2026, 11, 20);

  setUp(() {
    db = testDatabase();
    scanner = _Scanner();
    prober = _Prober();
    index = MediaIndex(
      db: db,
      scanner: scanner,
      prober: prober,
      now: () => now,
    );
  });
  tearDown(() async {
    await index.dispose();
    await db.close();
  });

  Future<void> settle() async {
    await index.refresh();
    // The background probe runs one file at a time.
    for (var i = 0; i < 50 && index.status.toProbe > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('finds, probes and thumbnails new files', () async {
    scanner.files = [_file('/m/Films/Heist.mkv'), _file('/m/Music/song.mp3')];
    await settle();
    final videos = await index.watch(MediaKind.video).first;
    expect(videos.single.name, 'Heist.mkv');
    expect(videos.single.folder, 'Films');
    expect(videos.single.width, 1920);
    expect(videos.single.durationMs, 180000);
    expect(videos.single.thumbnailPath, '/thumbs/Heist.mkv.jpg');
    expect(videos.single.added, now);
    final music = await index.watch(MediaKind.audio).first;
    expect(music.single.title, 'Song');
    expect(index.status.lastScan, now);
  });

  test('changed files are probed again, unchanged ones are not', () async {
    scanner.files = [_file('/m/a.mkv'), _file('/m/b.mkv')];
    await settle();
    expect(prober.probed, hasLength(2));
    final firstAdded = (await index.watch(MediaKind.video).first)
        .firstWhere((i) => i.uri == '/m/a.mkv')
        .added;

    now = DateTime(2026, 11, 21);
    scanner.files = [_file('/m/a.mkv', size: 200), _file('/m/b.mkv')];
    await settle();
    // Only the changed file is probed again.
    expect(prober.probed.where((u) => u == '/m/a.mkv'), hasLength(2));
    expect(prober.probed.where((u) => u == '/m/b.mkv'), hasLength(1));
    final a = (await index.watch(MediaKind.video).first).firstWhere(
      (i) => i.uri == '/m/a.mkv',
    );
    expect(a.size, 200);
    // Still "added" when first seen.
    expect(a.added, firstAdded);
  });

  test('removed files drop out', () async {
    scanner.files = [_file('/m/a.mkv'), _file('/m/b.mkv')];
    await settle();
    scanner.files = [_file('/m/b.mkv')];
    await settle();
    final videos = await index.watch(MediaKind.video).first;
    expect(videos.map((v) => v.uri), ['/m/b.mkv']);
  });

  test('Android details from the scan are kept', () async {
    scanner.files = [
      ScannedFile.fromMap(const {
        'uri': 'content://media/external/audio/media/7',
        'kind': 'audio',
        'name': 'track.flac',
        'folderPath': '/storage/emulated/0/Music/Album',
        'durationMs': 200000,
        'size': 5000,
        'addedS': 1700000000,
        'modifiedS': 1700000000,
        'title': 'Night',
        'artist': 'Kyn',
        'album': 'Album',
        'trackNo': 3,
      }),
    ];
    // Like AndroidMediaProber: no probe, just a thumbnail.
    index = MediaIndex(
      db: db,
      scanner: scanner,
      prober: _NoDetails(),
      now: () => now,
    );
    await settle();
    final song = (await index.watch(MediaKind.audio).first).single;
    expect(song.folder, 'Album');
    expect(song.durationMs, 200000);
    expect(song.artist, 'Kyn');
    expect(song.trackNo, 3);
    expect(song.added, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(song.probed, isTrue);
  });

  test('no access: nothing is scanned', () async {
    scanner.grant = false;
    await index.refresh(ask: true);
    expect(index.status.granted, isFalse);
    expect(scanner.scans, 0);
  });

  test('the folder scanner finds videos and music, skipping hidden', () async {
    final root = Directory.systemTemp.createTempSync('kyndrel_lib');
    addTearDown(() => root.deleteSync(recursive: true));
    for (final f in [
      'Films/Heist.MKV',
      'Films/notes.txt',
      'Music/Album/01 Night.flac',
      '.hidden/secret.mp4',
    ]) {
      File(p.join(root.path, f))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    final found = await FolderMediaScanner([root.path]).scan();
    expect(
      {for (final f in found) f.name: f.kind},
      {'Heist.MKV': MediaKind.video, '01 Night.flac': MediaKind.audio},
    );
    expect(found.firstWhere((f) => f.kind == MediaKind.audio).folder, 'Album');
  });

  test('default folders: Videos/Movies and Music in the home folder', () {
    final folders = FolderMediaScanner.defaultFolders(
      environment: {'HOME': '/home/r'},
    );
    expect(folders.last, p.join('/home/r', 'Music'));
    expect(
      folders.first,
      anyOf(p.join('/home/r', 'Videos'), p.join('/home/r', 'Movies')),
    );
  });

  test('a version 2 database gains the library table', () async {
    final v2 = NativeDatabase.memory(
      setup: (raw) {
        raw
          ..execute(
            'CREATE TABLE resume_points (source TEXT NOT NULL PRIMARY KEY, '
            'position_ms INTEGER NOT NULL, duration_ms INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          )
          ..execute('PRAGMA user_version = 2');
      },
    );
    final upgraded = KyndrelDatabase(DatabaseConnection(v2));
    addTearDown(upgraded.close);
    expect(await upgraded.select(upgraded.libraryItems).get(), isEmpty);
  });
}

class _NoDetails implements MediaProber {
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
