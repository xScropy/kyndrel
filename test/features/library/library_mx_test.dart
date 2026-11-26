import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:kyndrel/features/library/library_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/tiny_jpeg.dart';

ScannedFile _video(
  String path, {
  int minutes = 90,
  int height = 1080,
  DateTime? added,
  bool subtitles = false,
}) => ScannedFile(
  uri: path,
  name: path.split('/').last,
  folderPath: path.substring(0, path.lastIndexOf('/')),
  kind: MediaKind.video,
  size: 1000000,
  modified: DateTime(2026),
  added: added ?? DateTime(2026, 1, 10),
  duration: Duration(minutes: minutes),
  width: 1920,
  height: height,
  hasSubtitles: subtitles,
);

/// Task 8.6: the library like MX Player.
void main() {
  Future<AppHarness> library(
    WidgetTester tester, {
    List<ScannedFile>? files,
    Size size = const Size(1280, 720),
  }) async {
    final h = await AppHarness.create();
    h.scanner.files =
        files ??
        [
          _video('/m/Films/The Heist.mkv', added: clock.now()),
          _video('/m/Films/Arrival.mp4', subtitles: true),
          _video('/m/Clips/cat.mp4', minutes: 1, height: 720),
        ];
    await h.pump(tester, size: size);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.videos);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    // Menus are long now: scroll the item into view first.
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('views: all videos, recently added, playlists', (tester) async {
    await library(tester);
    await tap(tester, 'library-view-all');
    expect(find.byKey(const Key('video-cat.mp4')), findsOneWidget);
    expect(find.byKey(const Key('video-Arrival.mp4')), findsOneWidget);
    // Only what came in this month.
    await tap(tester, 'library-view-recent');
    expect(find.byKey(const Key('video-The Heist.mkv')), findsOneWidget);
    expect(find.byKey(const Key('video-cat.mp4')), findsNothing);
    await tap(tester, 'library-view-playlists');
    expect(find.byKey(const Key('playlist-smart-unwatched')), findsOneWidget);
    await tap(tester, 'playlist-smart-unwatched');
    expect(find.textContaining('3 videos'), findsOneWidget);
  });

  testWidgets('long-press selects; mark watched; add to a new playlist', (
    tester,
  ) async {
    final h = await library(tester);
    await tap(tester, 'folder-Films');
    await tester.longPress(find.byKey(const Key('video-Arrival.mp4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selection')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    // A tap now selects rather than plays.
    await tap(tester, 'video-The Heist.mkv');
    expect(find.text('2 selected'), findsOneWidget);
    expect(h.backend.calls.where((c) => c.startsWith('open(')), isEmpty);

    await tap(tester, 'selection-more');
    await tap(tester, 'selection-watched');
    final repo = LibraryRepository(h.db);
    final watched = (await tester.runAsync(
      () => repo
          .watchItems(
            MediaKind.video,
            filter: const LibraryFilter(unwatched: true),
          )
          .first,
    ))!;
    expect(watched.map((i) => i.name), ['cat.mp4']);
    expect(find.byKey(const Key('library-selection')), findsNothing);

    await tester.longPress(find.byKey(const Key('video-Arrival.mp4')));
    await tester.pumpAndSettle();
    await tap(tester, 'selection-all');
    await tap(tester, 'selection-playlist');
    await tap(tester, 'playlist-new');
    await tester.enterText(find.byKey(const Key('ask-text')), 'Weekend');
    await tap(tester, 'ask-ok');
    final lists = (await tester.runAsync(() => repo.watchPlaylists().first))!;
    expect(lists.single.$1.name, 'Weekend');
    expect(lists.single.$2, 2);

    await tap(tester, 'library-back');
    await tap(tester, 'library-view-playlists');
    await tap(tester, 'saved-playlist-Weekend');
    expect(find.byKey(const Key('playlist-items')), findsOneWidget);
    expect(find.text('Arrival.mp4'), findsOneWidget);
  });

  testWidgets('folders: pin to top, hide, show hidden', (tester) async {
    await library(tester);
    double top(String name) =>
        tester.getTopLeft(find.byKey(Key('folder-$name'))).dx;
    // Films has the newest video: first.
    expect(top('Films'), lessThan(top('Clips')));
    await tester.longPress(find.byKey(const Key('folder-Clips')));
    await tester.pumpAndSettle();
    await tap(tester, 'folder-action-pin');
    expect(top('Clips'), lessThan(top('Films')));

    await tester.longPress(find.byKey(const Key('folder-Clips')));
    await tester.pumpAndSettle();
    await tap(tester, 'folder-action-hide');
    expect(find.byKey(const Key('folder-Clips')), findsNothing);
    await tap(tester, 'library-menu');
    await tap(tester, 'library-show-hidden');
    expect(find.byKey(const Key('folder-Clips')), findsOneWidget);
  });

  testWidgets('private folders: a PIN hides and opens them', (tester) async {
    final h = await library(tester);
    await tester.longPress(find.byKey(const Key('folder-Clips')));
    await tester.pumpAndSettle();
    await tap(tester, 'folder-action-private');
    // No PIN yet: choose one.
    await tester.enterText(find.byKey(const Key('ask-text')), '1234');
    await tap(tester, 'ask-ok');
    expect(find.byKey(const Key('folder-Clips')), findsNothing);
    expect(h.container.read(settingsProvider).privatePin, isNotEmpty);

    await tap(tester, 'library-menu');
    await tap(tester, 'library-private');
    await tester.enterText(find.byKey(const Key('ask-text')), '0000');
    await tap(tester, 'ask-ok');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.byKey(const Key('folder-Clips')), findsNothing);

    await tap(tester, 'library-menu');
    await tap(tester, 'library-private');
    await tester.enterText(find.byKey(const Key('ask-text')), '1234');
    await tap(tester, 'ask-ok');
    expect(find.byKey(const Key('folder-Clips')), findsOneWidget);
  });

  testWidgets('a long list gets a fast-scroller with a letter bubble', (
    tester,
  ) async {
    final files = [
      for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
        for (var i = 0; i < 6; i++) _video('/m/Big/$c$i.mkv'),
    ];
    await library(tester, files: files, size: const Size(800, 600));
    await tap(tester, 'folder-Big');
    await tap(tester, 'library-menu');
    await tap(tester, 'sort-name');
    final strip = tester.getRect(find.byKey(const Key('fast-scroller')));
    final drag = await tester.startGesture(
      strip.topCenter + const Offset(0, 30),
    );
    await tester.pump();
    await drag.moveTo(strip.center);
    await tester.pump();
    expect(find.byKey(const Key('fast-scroller-bubble')), findsOneWidget);
    // Halfway through A–Z.
    final bubble = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('fast-scroller-bubble')),
        matching: find.byType(Text),
      ),
    );
    expect(bubble.data, anyOf('M', 'N'));
    await drag.up();
    await tester.pumpAndSettle();
    // The list jumped to the middle of the alphabet.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            RegExp(r'^video-[MN]\d')
                .hasMatch((w.key! as ValueKey<String>).value),
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('video-A0.mkv')), findsNothing);
  });

  testWidgets('compact rows; grid sizes; badges', (tester) async {
    await library(tester);
    await tap(tester, 'folder-Films');
    await tap(tester, 'library-menu');
    await tap(tester, 'layout-compact');
    expect(find.byType(LibraryThumbnail), findsNothing);
    expect(find.byKey(const Key('video-Arrival.mp4')), findsOneWidget);

    await tap(tester, 'library-menu');
    await tap(tester, 'layout-grid');
    // Grid tiles carry the quality and subtitle badges.
    expect(find.text('FHD'), findsNWidgets(2));
    expect(find.text('CC'), findsOneWidget);
    final medium = tester.getSize(find.byKey(const Key('video-Arrival.mp4')));
    await tap(tester, 'library-menu');
    await tap(tester, 'grid-small');
    final small = tester.getSize(find.byKey(const Key('video-Arrival.mp4')));
    expect(small.width, lessThan(medium.width));
  });

  testWidgets('the folder remembers its order and layout', (tester) async {
    await library(tester);
    await tap(tester, 'folder-Films');
    await tap(tester, 'library-menu');
    await tap(tester, 'layout-grid');
    await tap(tester, 'library-back');
    await tap(tester, 'folder-Clips');
    expect(find.byType(GridView), findsNothing, reason: 'Clips: a list');
    await tap(tester, 'library-back');
    await tap(tester, 'folder-Films');
    expect(find.byKey(const Key('library-videos')), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('hovering a thumbnail flips through its scenes', (tester) async {
    final h = await library(tester);
    // The coarse storyboard made in advance (8.4).
    final board = Storyboard.read(
      h.cacheDir,
      '/m/Films/Arrival.mp4',
      const Duration(minutes: 90),
    );
    Directory(board.levelDirectory(0)).createSync(recursive: true);
    File(board.sheetPath(0, 0)).writeAsBytesSync(tinyJpeg(width: 160));
    board
        .withLevel(board.levels[0].copyWith(sheets: {0}, complete: true))
        .writeSpec();
    await tap(tester, 'folder-Films');
    final thumb = find.descendant(
      of: find.byKey(const Key('video-Arrival.mp4')),
      matching: find.byType(LibraryThumbnail),
    );
    final rect = tester.getRect(thumb);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: rect.centerLeft - const Offset(20, 0));
    await mouse.moveTo(rect.center);
    await tester.pump();
    expect(find.byKey(const Key('scene-thumbnail-frame')), findsOneWidget);
    await mouse.moveTo(rect.centerLeft - const Offset(40, 0));
    await tester.pump();
    expect(find.byKey(const Key('scene-thumbnail-frame')), findsNothing);
  });
}
