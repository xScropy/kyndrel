import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/net/dlna_server.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/browse/browse_sources.dart';
import 'package:kyndrel/features/browse/browse_view.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// A device with `/disk/Films/{Heist.mkv, Arrival.mp4}` and a WebDAV server
/// that wants a password.
class _FakeBrowse extends BrowseService {
  final listed = <BrowseLocation>[];

  @override
  Future<List<BrowseEntry>> list(BrowseLocation location) async {
    listed.add(location);
    switch (location) {
      case LocalLocation(path: '/disk'):
        return [
          const BrowseEntry(
            name: 'Films',
            isFolder: true,
            location: LocalLocation('/disk/Films'),
          ),
        ];
      case LocalLocation(path: '/disk/Films'):
        return const [
          BrowseEntry(
            name: 'Arrival.mp4',
            isFolder: false,
            play: '/disk/Films/Arrival.mp4',
          ),
          BrowseEntry(
            name: 'Heist.mkv',
            isFolder: false,
            play: '/disk/Films/Heist.mkv',
          ),
        ];
      case ServerLocation(:final server):
        if (passwords[server.key] != 'pw') throw NeedsPassword(server);
        return [
          const BrowseEntry(
            name: 'Show.mkv',
            isFolder: false,
            play: 'https://nas/dav/Show.mkv',
            headers: ['Authorization: Basic x'],
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Future<List<DlnaServer>> discover() async => [
    DlnaServer(
      id: '1',
      name: 'Living room NAS',
      control: Uri.parse('http://nas/ctl'),
    ),
  ];
}

/// Task 8.7: Browse.
void main() {
  test('places: only folders that exist, found off the UI thread', () async {
    final home = Directory.systemTemp.createTempSync('kyndrel_home');
    addTearDown(() => home.deleteSync(recursive: true));
    final films = Directory(p.join(home.path, 'Films'))..createSync();
    final roots = await localRoots(
      libraryFolders: [films.path, p.join(home.path, 'gone')],
      environment: {'HOME': home.path, 'USER': 'nobody-here'},
    );
    final paths = roots.map((r) => r.path).toList();
    expect(paths.take(2), [home.path, films.path]);
    expect(paths, isNot(contains(p.join(home.path, 'gone'))));
    expect(roots.first.title, 'Home');
  });

  Future<(AppHarness, _FakeBrowse)> browse(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    final fake = _FakeBrowse();
    final h = await AppHarness.create(
      prefs: {
        'libraryFolders': ['/disk'],
        ...prefs,
      },
      overrides: [
        browseServiceProvider.overrideWithValue(fake),
        localRootsProvider.overrideWith(
          (ref) async => const [LocalLocation('/disk')],
        ),
      ],
    );
    await h.pump(tester);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.browse);
    await tester.pumpAndSettle();
    return (h, fake);
  }

  testWidgets('folders, breadcrumbs, and a file plays on through its folder', (
    tester,
  ) async {
    // localRoots only lists folders that exist: use a real one.
    final disk = Directory.systemTemp.createTempSync('kyndrel_disk');
    addTearDown(() => disk.deleteSync(recursive: true));
    final fake = _FakeBrowse();
    final h = await AppHarness.create(
      prefs: {
        'libraryFolders': [disk.path],
      },
      overrides: [browseServiceProvider.overrideWithValue(fake)],
    );
    await h.pump(tester);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.browse);
    // Not pumpAndSettle: the places spinner turns until they're found.
    await tester.pump();
    expect(find.byKey(const Key('browse-places')), findsOneWidget);
    expect(find.byKey(const Key('browse-roots-loading')), findsOneWidget);
    // The places are found off the UI thread (real file IO).
    final rootKey = Key('browse-root-${p.basename(disk.path)}');
    for (var i = 0; i < 20 && find.byKey(rootKey).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(rootKey));
    await tester.pumpAndSettle();
    expect(fake.listed.single, LocalLocation(disk.path));

    // Pretend the disk is /disk from here on.
    await h.container
        .read(browseProvider.notifier)
        .open(const LocalLocation('/disk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('browse-entry-Films')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browse-crumb-2')), findsOneWidget);
    // Back up through the breadcrumbs, and down again.
    await tester.tap(find.byKey(const Key('browse-crumb-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browse-entry-Films')), findsOneWidget);
    await tester.tap(find.byKey(const Key('browse-entry-Films')));
    await tester.pumpAndSettle();

    // A file plays, and the rest of its folder follows.
    await tester.tap(find.byKey(const Key('browse-entry-Heist.mkv')));
    await tester.pump();
    final queue = h.container.read(playlistProvider);
    expect(queue.items, ['/disk/Films/Arrival.mp4', '/disk/Films/Heist.mkv']);
    expect(queue.current, 1);
  });

  testWidgets('a server asks for its password once, then lists', (
    tester,
  ) async {
    const server = SavedServer(
      kind: ServerKind.webdav,
      name: 'NAS',
      address: 'https://nas/dav/',
      user: 'me',
    );
    final (h, fake) = await browse(
      tester,
      prefs: {
        'browseServers': [jsonEncode(server.toJson())],
      },
    );
    await tester.tap(find.byKey(const Key('browse-server-NAS')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browse-password')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('browse-password')), 'pw');
    await tester.tap(find.byKey(const Key('browse-password-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browse-entry-Show.mkv')), findsOneWidget);
    expect(fake.passwords[server.key], 'pw');
    // Never saved with the server.
    expect(
      h.container.read(settingsProvider).browseServers.single,
      isNot(contains('pw')),
    );
    await tester.tap(find.byKey(const Key('browse-play-all')));
    await tester.pump();
    expect(h.container.read(playlistProvider).items, [
      'https://nas/dav/Show.mkv',
    ]);
  });

  testWidgets('add a server; media servers on the network', (tester) async {
    final (h, _) = await browse(tester);
    await tester.tap(find.byKey(const Key('browse-add-server')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('server-name')), 'Box');
    await tester.enterText(
      find.byKey(const Key('server-address')),
      'ftp://192.168.1.10/',
    );
    await tester.tap(find.byKey(const Key('server-save')));
    await tester.pumpAndSettle();
    final saved = savedServers(h.container.read(settingsProvider));
    expect(saved.single.name, 'Box');
    expect(saved.single.kind, ServerKind.ftp, reason: 'from the address');
    expect(find.byKey(const Key('browse-server-Box')), findsOneWidget);

    await tester.tap(find.byKey(const Key('browse-discover')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('browse-dlna-Living room NAS')),
      findsOneWidget,
    );
  });

  test(
    'local listing: folders and playable files, hidden ones skipped',
    () async {
      final dir = Directory.systemTemp.createTempSync('kyndrel_browse');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final f in ['Ep 10.mkv', 'Ep 2.mkv', 'notes.txt', '.hidden.mkv']) {
        File(p.join(dir.path, f)).writeAsStringSync('x');
      }
      Directory(p.join(dir.path, 'Season 1')).createSync();
      Directory(p.join(dir.path, '.cache')).createSync();
      final entries = await BrowseService().list(LocalLocation(dir.path));
      expect(entries.map((e) => e.name), ['Season 1', 'Ep 2.mkv', 'Ep 10.mkv']);
      expect(
        entries.first.location,
        LocalLocation(p.join(dir.path, 'Season 1')),
      );
    },
  );
}
