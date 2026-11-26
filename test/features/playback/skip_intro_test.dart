import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/intro_repository.dart';
import 'package:kyndrel/features/playback/skip_intro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 8.9: skip intro and credits.
void main() {
  testWidgets('a chapter called Opening offers "Skip intro"', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load(duration: const Duration(minutes: 10));
    h.backend.properties
      ..['chapter-list/0/time'] = '0'
      ..['chapter-list/0/title'] = 'Opening'
      ..['chapter-list/1/time'] = '90'
      ..['chapter-list/1/title'] = 'Part 1';
    h.backend.emitProperty('chapter-list/count', '2');
    h.backend.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump();
    expect(find.text('Skip intro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('skip-intro')));
    await tester.pump();
    expect(h.backend.calls.last, 'seek(90000)');
    h.backend.emitPosition(const Duration(seconds: 120));
    await tester.pump();
    expect(find.byKey(const Key('skip-intro')), findsNothing);
  });

  testWidgets('Shift+M twice marks the intro for the whole season', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/v/Show.S01E01.mkv'),
    );
    h.load(duration: const Duration(minutes: 40));
    Future<void> mark(Duration at) async {
      h.backend.emitPosition(at);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
    }

    await mark(const Duration(seconds: 50));
    await mark(const Duration(seconds: 110));
    final saved = await tester.runAsync(
      () => h.container
          .read(introRepositoryProvider)
          .get(IntroRepository.showKey('Show', 1)),
    );
    expect((saved?.introStartMs, saved?.introEndMs), (50000, 110000));
    expect(saved?.manual, isTrue);

    // Another episode of the season gets it too.
    await h.service.open('/v/Show.S01E02.mkv');
    h.load(duration: const Duration(minutes: 40));
    h.backend.emitPosition(const Duration(seconds: 60));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Skip intro'), findsOneWidget);
  });

  testWidgets("found by comparing two episodes' storyboards", (tester) async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_show');
    addTearDown(() => dir.deleteSync(recursive: true));
    final ep1 = p.join(dir.path, 'Show.S01E01.mkv');
    final ep2 = p.join(dir.path, 'Show.S01E02.mkv');
    for (final f in [ep1, ep2]) {
      File(f).writeAsStringSync('x');
    }
    final h = await AppHarness.create();
    const length = Duration(minutes: 10);
    // The same 60 s opening: from 0:20 in episode 2, from 0:00 in 1.
    await tester.runAsync(() async {
      _writeBoard(h.cacheDir, ep1, length, introAt: 0, seed: 1);
      _writeBoard(h.cacheDir, ep2, length, introAt: 10, seed: 2);
    });
    await h.pump(tester, launch: LaunchOptions(source: ep2));
    h.load(duration: length);
    await tester.pump();
    // The storyboard is already made: the controller reads it, then
    // compares in an isolate.
    await tester.pump(StoryboardController.delay);
    await tester.pump();
    // Two isolates, one after the other: real time, then a frame.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    final ranges = h.container.read(skipIntroProvider);
    expect(ranges.introStart, const Duration(seconds: 20));
    expect(ranges.introEnd, const Duration(seconds: 80));
    // Saved for both episodes.
    final other = await tester.runAsync(
      () => h.container.read(introRepositoryProvider).get(ep1),
    );
    expect(other?.introEndMs, 60000);
  });
}

/// A finished storyboard for [source] whose frames are random pictures,
/// except a shared 30-frame (60 s) opening starting at fine frame
/// [introAt].
void _writeBoard(
  Directory cache,
  String source,
  Duration length, {
  required int introAt,
  required int seed,
}) {
  final rnd = math.Random(seed);
  img.Image picture(int s) {
    final r = math.Random(s);
    final im = img.Image(width: 32, height: 18);
    for (var x = 0; x < 32; x++) {
      for (var y = 0; y < 18; y++) {
        final v = r.nextInt(256);
        im.setPixelRgb(x, y, v, v, v);
      }
    }
    return im;
  }

  var board = Storyboard.read(cache, source, length);
  for (final level in board.levels) {
    final spec = level.spec;
    final n = spec.index;
    Directory(board.levelDirectory(n)).createSync(recursive: true);
    for (var s = 0; s < spec.sheetCount; s++) {
      final sheet = img.Image(width: spec.cols * 32, height: spec.rows * 18);
      for (final i in spec.framesOf(s)) {
        final shared = n == 1 && i >= introAt && i < introAt + 30;
        final cell = picture(
          shared ? 10000 + i - introAt : rnd.nextInt(1 << 30),
        );
        img.compositeImage(
          sheet,
          cell,
          dstX: (i % spec.perSheet % spec.cols) * 32,
          dstY: (i % spec.perSheet ~/ spec.cols) * 18,
        );
      }
      File(board.sheetPath(n, s))
          .writeAsBytesSync(img.encodeJpg(sheet, quality: 90));
    }
    board = board.withLevel(
      level.copyWith(
        sheets: {for (var s = 0; s < spec.sheetCount; s++) s},
        complete: true,
      ),
    );
  }
  board.writeSpec();
}
