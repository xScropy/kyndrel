import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/storage/bookmark_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:kyndrel/features/playback/widgets/diagnostics_overlay.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

/// Task 8.8: bookmarks, jump to time, statistics, decoder switch.
void main() {
  test('jump to time: what can be typed', () {
    const hour = Duration(hours: 1);
    expect(
      parseTimeInput('1:02:03'),
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    expect(parseTimeInput('83:10'), const Duration(minutes: 83, seconds: 10));
    expect(parseTimeInput('90'), const Duration(seconds: 90));
    expect(parseTimeInput(' 12.5 '), const Duration(milliseconds: 12500));
    expect(parseTimeInput('50%', duration: hour), const Duration(minutes: 30));
    expect(parseTimeInput('3:00:00', duration: hour), hour, reason: 'clamped');
    for (final bad in ['', 'abc', '1:2:3:4', '-5', '50%']) {
      expect(parseTimeInput(bad), isNull, reason: bad);
    }
  });

  Future<AppHarness> playing(WidgetTester tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    h.backend.emitPosition(const Duration(minutes: 12, seconds: 34));
    await tester.pump();
    return h;
  }

  testWidgets('B bookmarks here; ticks on the bar; the list jumps', (
    tester,
  ) async {
    final h = await playing(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    final marks = (await tester.runAsync(
      () => h.container
          .read(bookmarkRepositoryProvider)
          .watch('/v/film.mkv')
          .first,
    ))!;
    expect(marks.single.label, '12:34');
    await tester.pump(const Duration(milliseconds: 100));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<SeekBarPainter>()
        .first;
    expect(painter.bookmarks.single, closeTo(754 / 3600, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookmarks-dialog')), findsOneWidget);
    h.backend.emitPosition(Duration.zero);
    await tester.tap(find.byKey(const Key('bookmark-12:34')));
    await tester.pumpAndSettle();
    expect(h.backend.calls.last, 'seek(754000)');
  });

  testWidgets('Ctrl+G jumps to a typed time', (tester) async {
    final h = await playing(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('prompt-text')), '45:00');
    await tester.tap(find.byKey(const Key('prompt-ok')));
    await tester.pumpAndSettle();
    expect(h.backend.calls.last, 'seek(2700000)');
  });

  testWidgets('H switches HW → HW+ → SW; Shift+I shows statistics', (
    tester,
  ) async {
    final h = await playing(tester);
    expect(find.text('HW'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(h.container.read(settingsProvider).hwdec, 'auto-copy');
    expect(find.text('HW+'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decoder-button')));
    await tester.pump();
    expect(h.container.read(settingsProvider).hwdec, 'no');
    expect(find.text('SW'), findsOneWidget);

    expect(find.byType(DiagnosticsOverlay), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byType(DiagnosticsOverlay), findsOneWidget);
    expect(DecoderActions.label('mediacodec-copy'), 'HW+');
  });
}
