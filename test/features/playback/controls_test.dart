import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/harbor_icons.g.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:kyndrel/features/playback/widgets/transport_controls.dart';
import 'package:kyndrel/features/playback/widgets/volume_control.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
  group('seek bar', () {
    Future<AppHarness> setup(WidgetTester tester) async {
      final h = await AppHarness.create();
      await h.pumpWidget(
        tester,
        const Padding(padding: EdgeInsets.all(40), child: SeekBarRow()),
        size: const Size(864, 120),
      );
      await h.service.open('/v/a.mkv');
      h.backend
        ..emitDuration(const Duration(minutes: 10))
        ..emitPosition(const Duration(minutes: 2, seconds: 30))
        ..emitBuffer(const Duration(minutes: 1));
      await tester.pump();
      return h;
    }

    // The bar spans x = 104..760 (40 padding + 64 label each side).
    const left = 104.0;
    const width = 656.0;

    testWidgets('labels show elapsed and total, tap toggles remaining', (
      tester,
    ) async {
      final h = await setup(tester);
      expect(find.text('2:30'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('seek-total')));
      await tester.pump();
      expect(find.text('-7:30'), findsOneWidget);
      expect(h.container.read(settingsProvider).showRemainingTime, isTrue);
    });

    testWidgets('click seeks to that point', (tester) async {
      final h = await setup(tester);
      h.backend.calls.clear();
      await tester.tapAt(const Offset(left + width * 0.75, 60));
      await tester.pump();
      expect(h.backend.calls, ['seek(450000)']);
    });

    testWidgets('hover shows the time under the pointer', (tester) async {
      await setup(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(left + width * 0.5, 60));
      await tester.pump();
      expect(find.byKey(const Key('seek-hover-time')), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
    });

    testWidgets('drag seeks at most every 120 ms and once more on release', (
      tester,
    ) async {
      final h = await setup(tester);
      h.backend.calls.clear();
      final g = await tester.startGesture(const Offset(left + 10, 60));
      for (var i = 1; i <= 20; i++) {
        await g.moveTo(Offset(left + 10 + i * 30.0, 60));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      final seeks = h.backend.calls.where((c) => c.startsWith('seek')).toList();
      // ~320 ms of dragging → a few throttled seeks, not 20.
      expect(seeks.length, inInclusiveRange(2, 6));
      // Final position: x = left + 610 → 610/656 of 10 min.
      final last = int.parse(seeks.last.replaceAll(RegExp('[^0-9]'), ''));
      expect(last, closeTo(600000 * 610 / 656, 2));
    });

    testWidgets('chapter marks and the chapter name on hover', (tester) async {
      final h = await setup(tester);
      h.backend.properties
        ..['chapter-list/0/time'] = '0'
        ..['chapter-list/0/title'] = 'Opening'
        ..['chapter-list/1/time'] = '300'
        ..['chapter-list/1/title'] = 'The Heist';
      h.backend.emitProperty('chapter-list/count', '2');
      await tester.pump();
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(left + width * 0.75, 60));
      await tester.pump();
      expect(find.text('The Heist'), findsOneWidget);
      await mouse.moveTo(const Offset(left + width * 0.25, 60));
      await tester.pump();
      expect(find.text('Opening'), findsOneWidget);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<SeekBarPainter>()
          .single;
      expect(painter.marks, [0.5]);
    });

    testWidgets('hovering asks for a preview frame', (tester) async {
      final h = await setup(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      for (final f in [0.1, 0.2, 0.5]) {
        await mouse.moveTo(Offset(left + width * f, 60));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 100));
      // Debounced: only the resting position is rendered.
      expect(h.previews.requests, [const Duration(minutes: 5)]);
    });

    testWidgets('golden', (tester) async {
      await setup(tester);
      await expectLater(
        find.byType(SeekBarRow),
        matchesGoldenFile('goldens/seek_bar.png'),
      );
    });
  });

  group('volume', () {
    Future<AppHarness> setup(WidgetTester tester) async {
      final h = await AppHarness.create();
      await h.pumpWidget(
        tester,
        const Padding(padding: EdgeInsets.all(20), child: VolumeControl()),
        size: const Size(300, 80),
      );
      return h;
    }

    Rect slider(WidgetTester t) =>
        t.getRect(find.byKey(const Key('volume-slider')));

    testWidgets('slider covers 0–500, 100 % at 64 %, and snaps to 100', (
      tester,
    ) async {
      final h = await setup(tester);
      final r = slider(tester);
      await tester.tapAt(Offset(r.right - 0.5, r.center.dy));
      await tester.pump();
      expect(h.service.state.volume, closeTo(500, 5));
      await tester.tapAt(Offset(r.left + r.width * 0.32, r.center.dy));
      await tester.pump();
      expect(h.service.state.volume, closeTo(50, 1));

      // Just off the 100 % marker snaps onto it.
      await tester.tapAt(Offset(r.left + r.width * 0.62, r.center.dy));
      await tester.pump();
      expect(h.service.state.volume, 100);
      await tester.pump();
      expect(h.container.read(settingsProvider).volume, 100);
    });

    testWidgets('boosting adds the limiter and is persisted', (tester) async {
      final h = await setup(tester);
      final r = slider(tester);
      await tester.tapAt(Offset(r.left + r.width * 0.82, r.center.dy));
      await tester.pump();
      expect(h.service.state.volume, closeTo(300, 4));
      expect(h.backend.commands.last.first, 'af');
      expect(h.container.read(settingsProvider).volume, closeTo(300, 4));
      expect(h.container.read(settingsProvider).boostWarningSeen, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('mute button', (tester) async {
      final h = await setup(tester);
      await tester.tap(find.byKey(const Key('mute')));
      await tester.pump();
      expect(h.service.state.isMuted, isTrue);
      final mute = tester.widget<ControlButton>(
        find.byKey(const Key('mute')),
      );
      expect(mute.harbor, HarborIcons.volumeMute);
    });

    testWidgets('golden at 255 %', (tester) async {
      final h = await setup(tester);
      await h.service.setVolume(255);
      await tester.pump();
      await expectLater(
        find.byType(VolumeControl),
        matchesGoldenFile('goldens/volume_255.png'),
      );
    });
  });

  testWidgets('transport buttons use the configured skip length', (
    tester,
  ) async {
    final h = await AppHarness.create(prefs: {'skipSeconds': 30});
    await h.pumpWidget(tester, const Center(child: TransportControls()));
    await h.service.open('/v/a.mkv');
    h.backend
      ..emitDuration(const Duration(minutes: 10))
      ..emitPosition(const Duration(minutes: 5));
    await tester.pump();
    h.backend.calls.clear();
    expect(find.text('30'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('skip-forward')));
    await tester.tap(find.byKey(const Key('skip-back')));
    await tester.tap(find.byKey(const Key('play-pause')));
    expect(h.backend.calls, ['seek(330000)', 'seek(270000)', 'play']);
  });
}
