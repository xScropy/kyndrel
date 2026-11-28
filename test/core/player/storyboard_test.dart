import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 7.2: frames for the whole video, made in advance.
void main() {
  group('levels and lookup', () {
    test('a coarse level of 100 frames, then one every 2 s up to 300', () {
      expect(
        Storyboard.stepFor(const Duration(minutes: 5)),
        const Duration(seconds: 2),
      );
      expect(
        Storyboard.stepFor(const Duration(hours: 1)),
        const Duration(seconds: 12),
      );
      final film = StoryboardLevel.forVideo(const Duration(hours: 2));
      expect(film.map((l) => l.count), [100, 300]);
      expect(film.map((l) => l.width), [96, 160]);
      expect(film[0].sheetCount, 1, reason: 'one small sheet, like YouTube');
      expect(film[1].sheetCount, 12);
      // Phones get sharper frames too.
      final phone = StoryboardLevel.forVideo(
        const Duration(hours: 2),
        sharp: true,
      );
      expect(phone.map((l) => l.width), [96, 160, 320]);
      // A 30 s clip: one coarse frame a second.
      expect(
        StoryboardLevel.forVideo(const Duration(seconds: 30))[0].count,
        30,
      );
    });

    test('coarse to fine: the whole video is covered first', () {
      expect(coarseToFine(5), [0, 4, 2, 1, 3]);
      final order = coarseToFine(300);
      expect(order.toSet(), hasLength(300));
      expect(order.take(3), [0, 256, 128]);
      // After 10 frames, no gap is wider than an eighth of the video.
      final first = order.take(10).toList()..sort();
      for (var i = 1; i < first.length; i++) {
        expect(first[i] - first[i - 1], lessThanOrEqualTo(64));
      }
    });

    test('a sheet cell is a rectangle of the sheet', () {
      const f = FrameRef('/s.jpg', cell: 7, cols: 5, rows: 5);
      expect(f.sourceRect(800, 450), const Rect.fromLTWH(320, 90, 160, 90));
      expect(
        const FrameRef('/t.jpg').sourceRect(160, 90),
        const Rect.fromLTWH(0, 0, 160, 90),
      );
    });

    test('the best frame: the finest level that has it, else coarse', () {
      final specs = StoryboardLevel.forVideo(const Duration(seconds: 200));
      final board = Storyboard(
        source: '/v/f.mkv',
        duration: const Duration(seconds: 200),
        directory: '/c',
        levels: [
          // The coarse sheet is packed; frame 30 couldn't be made.
          LevelFrames(specs[0], sheets: const {0}, failed: const {30}),
          // Fine: frame 7 (14 s) is a loose tile so far.
          LevelFrames(specs[1], tiles: const {7}),
        ],
      );
      expect(
        board.nearest(const Duration(seconds: 14)),
        const FrameRef('/c/L1/tiles/7.jpg'),
      );
      expect(
        board.nearest(const Duration(seconds: 100)),
        const FrameRef('/c/L0/s0.jpg', cell: 50, cols: 10, rows: 10),
      );
      // The failed coarse frame: its neighbour.
      expect(
        board.nearest(const Duration(seconds: 60)),
        const FrameRef('/c/L0/s0.jpg', cell: 29, cols: 10, rows: 10),
      );
      expect(board.nearest(Duration.zero, maxLevel: 0)?.cell, 0);
      final empty = Storyboard(
        source: '/v/f.mkv',
        duration: const Duration(seconds: 200),
        directory: '/c',
        levels: [for (final s in specs) LevelFrames(s)],
      );
      expect(empty.nearest(Duration.zero), isNull);
      expect(empty.progress, 0);
    });

    test('the cache keeps the newest storyboards under its limit', () async {
      final cache = Directory.systemTemp.createTempSync('kyndrel_sb');
      addTearDown(() => cache.deleteSync(recursive: true));
      final dirs = <Directory>[];
      for (var i = 0; i < 3; i++) {
        final d = Directory(p.join(cache.path, 'storyboards', 'b$i'))
          ..createSync(recursive: true);
        File(p.join(d.path, 's0.jpg'))
          ..writeAsBytesSync(List.filled(1000, 1))
          ..setLastModifiedSync(DateTime(2026, 1, i + 1));
        dirs.add(d);
      }
      // Room for two: the oldest goes, unless it is the one in use.
      await Storyboard.trimCache(cache, limit: 2000, keep: dirs[0].path);
      expect(dirs.map((d) => d.existsSync()), [true, false, true]);
    });

    test('what is on disk: spec, sheets, loose tiles; old format goes', () {
      final cache = Directory.systemTemp.createTempSync('kyndrel_sb');
      addTearDown(() => cache.deleteSync(recursive: true));
      const length = Duration(seconds: 30);
      var board = Storyboard.read(cache, '/v/a.mkv', length);
      expect(board.levels.every((l) => l.tiles.isEmpty), isTrue);
      expect(board.complete, isFalse);

      // A render in progress: tiles, no spec yet.
      Directory(board.tilesDirectory(1)).createSync(recursive: true);
      File(board.tilePath(1, 4)).writeAsBytesSync([1]);
      File(p.join(board.tilesDirectory(1), '5.part')).writeAsBytesSync([1]);
      board = Storyboard.read(cache, '/v/a.mkv', length);
      expect(board.levels[1].tiles, {4});

      // Finished: the spec says so.
      final l0 = board.levels[0];
      final l1 = board.levels[1];
      board
          .withLevel(l0.copyWith(sheets: {0}, complete: true))
          .withLevel(
            l1.copyWith(sheets: {0}, failed: {3}, tiles: {}, complete: true),
          )
          .writeSpec();
      board = Storyboard.read(cache, '/v/a.mkv', length);
      expect(board.complete, isTrue);
      expect(board.levels[1].failed, {3});
      expect(board.levels[1].has(3), isFalse);
      expect(board.levels[1].has(4), isTrue);

      // Another length means other levels: not complete.
      expect(
        Storyboard.read(cache, '/v/a.mkv', const Duration(hours: 1)).complete,
        isFalse,
      );

      // A 7.2 storyboard (one file per frame) is deleted.
      final old = Storyboard.directoryFor(cache, '/v/old.mkv');
      Directory(old).createSync(recursive: true);
      File(p.join(old, '0.jpg')).writeAsBytesSync([1]);
      File(p.join(old, 'index.json')).writeAsStringSync('{"stepMs":2000}');
      expect(
        Storyboard.read(cache, '/v/old.mkv', length).levels[0].tiles,
        isEmpty,
      );
      expect(Directory(old).existsSync(), isFalse);
    });
  });

  testWidgets('made 2 s after a file starts, and shown at once on the bar', (
    tester,
  ) async {
    final h = await AppHarness.create();
    h.previews.path = '/tmp/exact.jpg';
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    expect(h.storyboards.rendered, isEmpty);
    await tester.pump(StoryboardController.delay);
    await tester.pump();
    expect(h.storyboards.rendered, hasLength(1));
    final board = h.container.read(storyboardProvider)!;
    expect(board.complete, isTrue);
    expect(board.source, '/v/film.mkv');

    // Hover the middle of the seek bar: the storyboard frame, no render.
    final bar = tester.getRect(find.byKey(const Key('seek-bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: bar.centerLeft);
    await mouse.moveTo(bar.center);
    await tester.pump();
    FrameRef frame() => tester
        .widget<FrameView>(
          find.descendant(
            of: find.byKey(const Key('seek-preview')),
            matching: find.byType(FrameView),
          ),
        )
        .frame;
    expect(frame().path, startsWith(board.directory));
    expect(h.previews.exactRequests, isEmpty);

    // Resting there: the exact frame replaces it.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(h.previews.exactRequests, hasLength(1));
    expect(frame(), const FrameRef('/tmp/exact.jpg'));
  });

  testWidgets('moving over the bar repaints it, never rebuilds it (8.3)', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    await tester.pump(StoryboardController.delay);
    await tester.pump();
    final bar = tester.getRect(find.byKey(const Key('seek-bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: bar.centerLeft);
    await mouse.moveTo(bar.centerLeft + const Offset(4, 0));
    await tester.pump();
    final before = SeekBar.debugBuilds;
    for (var i = 1; i <= 30; i++) {
      await mouse.moveTo(bar.centerLeft + Offset(i * bar.width / 32, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(SeekBar.debugBuilds - before, 0);
    expect(find.byKey(const Key('seek-preview')), findsOneWidget);
    expect(find.byKey(const Key('seek-hover-time')), findsOneWidget);
    // Frames near the pointer were asked for first.
    expect(h.storyboards.focused, isEmpty, reason: 'already complete');
  });

  testWidgets('streams get no storyboard', (tester) async {
    final h = await AppHarness.create();
    await h.pump(
      tester,
      launch: const LaunchOptions(source: 'https://example.com/a.m3u8'),
    );
    h.load();
    await tester.pump(const Duration(seconds: 3));
    expect(h.storyboards.rendered, isEmpty);
    expect(h.container.read(storyboardProvider), isNull);
  });
}
