import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 7.2: frames for the whole video, made in advance.
void main() {
  group('spacing and lookup', () {
    test('every 2 s up to 10 minutes, then 300 frames', () {
      expect(
        Storyboard.stepFor(const Duration(minutes: 5)),
        const Duration(seconds: 2),
      );
      expect(
        Storyboard.stepFor(const Duration(hours: 1)),
        const Duration(seconds: 12),
      );
      final film = Storyboard(
        source: '/v/f.mkv',
        duration: const Duration(hours: 2),
        step: Storyboard.stepFor(const Duration(hours: 2)),
        directory: '/c',
      );
      expect(film.count, 300);
    });

    test('the nearest written frame', () {
      const board = Storyboard(
        source: '/v/f.mkv',
        duration: Duration(seconds: 20),
        step: Duration(seconds: 2),
        directory: '/c',
        available: {0, 3, 9},
      );
      expect(board.nearest(const Duration(seconds: 6)), '/c/3.jpg');
      expect(board.nearest(const Duration(milliseconds: 6900)), '/c/3.jpg');
      expect(board.nearest(const Duration(seconds: 15)), '/c/9.jpg');
      expect(board.nearest(Duration.zero), '/c/0.jpg');
      expect(board.copyWith(available: {}).nearest(Duration.zero), isNull);
      expect(board.progress, 0.3);
    });

    test('the cache keeps the newest storyboards under its limit', () {
      final cache = Directory.systemTemp.createTempSync('kyndrel_sb');
      addTearDown(() => cache.deleteSync(recursive: true));
      final dirs = <Directory>[];
      for (var i = 0; i < 3; i++) {
        final d = Directory(p.join(cache.path, 'storyboards', 'b$i'))
          ..createSync(recursive: true);
        File(p.join(d.path, '0.jpg'))
          ..writeAsBytesSync(List.filled(1000, 1))
          ..setLastModifiedSync(DateTime(2026, 1, i + 1));
        dirs.add(d);
      }
      // Room for two: the oldest goes, unless it is the one in use.
      Storyboard.trimCache(cache, limit: 2000, keep: dirs[0].path);
      expect(dirs.map((d) => d.existsSync()), [true, false, true]);
    });

    test('what is on disk, and when it is complete', () {
      final cache = Directory.systemTemp.createTempSync('kyndrel_sb');
      addTearDown(() => cache.deleteSync(recursive: true));
      const length = Duration(seconds: 10);
      var board = Storyboard.read(cache, '/v/a.mkv', length);
      expect(board.available, isEmpty);
      Directory(board.directory).createSync(recursive: true);
      File(board.pathOf(2)).writeAsBytesSync([1]);
      File(p.join(board.directory, '3.part')).writeAsBytesSync([1]);
      board = Storyboard.read(cache, '/v/a.mkv', length);
      expect(board.available, {2});
      expect(board.complete, isFalse);
      board.writeIndex();
      expect(Storyboard.read(cache, '/v/a.mkv', length).complete, isTrue);
      // A different length means a different spacing: not complete.
      expect(
        Storyboard.read(cache, '/v/a.mkv', const Duration(hours: 1)).complete,
        isFalse,
      );
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
    Image frame() => tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('seek-preview')),
        matching: find.byType(Image),
      ),
    );
    expect((frame().image as FileImage).file.path, startsWith(board.directory));
    expect(h.previews.exactRequests, isEmpty);

    // Resting there: the exact frame replaces it.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(h.previews.exactRequests, hasLength(1));
    expect((frame().image as FileImage).file.path, '/tmp/exact.jpg');
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
