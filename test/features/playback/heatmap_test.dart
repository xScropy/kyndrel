import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/storage/replay_repository.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/test_database.dart';

/// Task 8.10: what gets watched again, shaded over the seek bar.
void main() {
  test('replays count per hundredth of the file', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = ReplayRepository(db);
    await repo.addRange('/v/a.mkv', 0.10, 0.125);
    await repo.addRange('/v/a.mkv', 0.12, 0.13);
    final counts = await repo.watch('/v/a.mkv').first;
    expect(counts.sublist(9, 15), [0, 1, 1, 2, 1, 0]);
    expect(ReplayRepository.bucketOf(1), 99);
    expect((await repo.watch('/v/b.mkv').first).every((c) => c == 0), isTrue);
  });

  Future<AppHarness> playing(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    final h = await AppHarness.create(prefs: prefs);
    await h.pump(tester, launch: const LaunchOptions(source: '/v/a.mkv'));
    h.load(duration: const Duration(minutes: 100));
    await tester.pump();
    return h;
  }

  Future<List<int>> counts(WidgetTester tester, AppHarness h) async =>
      (await tester.runAsync(
        () => ReplayRepository(h.db).watch('/v/a.mkv').first,
      ))!;

  testWidgets('jumping back counts; the bar shades it on hover', (
    tester,
  ) async {
    final h = await playing(tester);
    h.backend.emitPosition(const Duration(minutes: 30));
    await tester.pump();
    // Back 3 minutes: 27–30 min replayed.
    h.backend.emitPosition(const Duration(minutes: 27));
    await tester.pump(const Duration(milliseconds: 100));
    // A tiny step back is not a replay; a jump of an hour is a seek.
    h.backend
      ..emitPosition(const Duration(minutes: 26, seconds: 59))
      ..emitPosition(const Duration(minutes: 90))
      ..emitPosition(const Duration(minutes: 10));
    await tester.pump(const Duration(milliseconds: 100));
    final c = await counts(tester, h);
    expect(
      [
        for (var i = 0; i < 100; i++)
          if (c[i] > 0) i,
      ],
      [27, 28, 29, 30],
    );

    final bar = tester.getRect(find.byKey(const Key('seek-bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: bar.centerLeft - const Offset(5, 0));
    await mouse.moveTo(bar.center);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<SeekBarPainter>()
        .first;
    expect(painter.heat, hasLength(100));
    expect(painter.heat[28], 1);
    expect(painter.heat[50], 0);
  });

  testWidgets('incognito records nothing; the setting hides it', (
    tester,
  ) async {
    final h = await playing(
      tester,
      prefs: {'incognito': true, 'showHeatmap': false},
    );
    h.backend
      ..emitPosition(const Duration(minutes: 30))
      ..emitPosition(const Duration(minutes: 27));
    await tester.pump(const Duration(milliseconds: 100));
    expect((await counts(tester, h)).every((c) => c == 0), isTrue);
  });
}
