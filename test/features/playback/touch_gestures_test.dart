import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/brightness_service.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/system_volume.dart';
import 'package:kyndrel/core/player/video_view_settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_platform_services.dart';

/// Task 6.3: touch gestures on a 1280×720 player.
void main() {
  late FakeBrightness brightness;
  late FakeSystemVolume phoneVolume;

  Future<AppHarness> phone(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    brightness = FakeBrightness();
    phoneVolume = FakeSystemVolume();
    final h = await AppHarness.create(
      prefs: prefs,
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.phone,
        ),
        brightnessServiceProvider.overrideWithValue(brightness),
        systemVolumeProvider.overrideWithValue(phoneVolume),
      ],
    );
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    h.backend.emitPosition(const Duration(minutes: 10));
    await tester.pump();
    h.backend.calls.clear();
    return h;
  }

  /// A vertical swipe of [dy] px starting at [x], in small steps.
  Future<void> swipe(
    WidgetTester tester, {
    required double x,
    required double dy,
    double y = 500,
  }) async {
    final finger = await tester.startGesture(Offset(x, y));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await finger.moveTo(Offset(x, y + dy * i / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pump();
  }

  OsdLevel? level(AppHarness h) => h.container.read(levelOsdProvider);

  group('combined volume scale', () {
    test('phone volume first, then the boost', () {
      expect(CombinedVolume.of(system: 0.5, player: 100), 50);
      expect(CombinedVolume.of(system: 1, player: 160), 160);
      expect(CombinedVolume.split(40), (system: 0.4, player: 100.0));
      expect(CombinedVolume.split(150), (system: 1.0, player: 150.0));
      expect(CombinedVolume.split(999).player, CombinedVolume.max);
    });
  });

  testWidgets('right-side swipe up: phone volume to max, then boost', (
    tester,
  ) async {
    final h = await phone(tester);
    // 50 % (32 % of the scale) up half the range → 82 %, 300 %:
    // 0.5 × 0.8 × 720 px.
    await swipe(tester, x: 1000, dy: -288);
    expect(phoneVolume.value, 1);
    expect(h.service.state.volume, closeTo(300, 4));
    expect(level(h)?.kind, LevelKind.volume);
    expect(level(h)?.isBoost, isTrue);
    expect(find.byKey(const Key('level-osd')), findsOneWidget);

    // Back down below 100 %: Kyndrel returns to 100, the phone goes down.
    await swipe(tester, x: 1000, dy: 288);
    expect(h.service.state.volume, 100);
    expect(phoneVolume.value, closeTo(0.5, 0.02));
  });

  testWidgets('left-side swipe changes the brightness only', (tester) async {
    final h = await phone(tester);
    await swipe(tester, x: 200, dy: -173); // +0.3 of the range
    expect(brightness.value, closeTo(0.8, 0.02));
    expect(level(h)?.kind, LevelKind.brightness);
    expect(h.service.state.volume, 100);
    expect(phoneVolume.value, 0.5);
  });

  testWidgets('swipes from the screen edges are left to the system', (
    tester,
  ) async {
    await phone(tester);
    await swipe(tester, x: 10, dy: -300);
    await swipe(tester, x: 1270, dy: -300);
    expect(brightness.value, 0.5);
    expect(phoneVolume.value, 0.5);
  });

  testWidgets('double-tap the sides skips and adds up; middle pauses', (
    tester,
  ) async {
    final h = await phone(tester);
    Future<void> doubleTap(double x) async {
      await tester.tapAt(Offset(x, 360));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(Offset(x, 360));
      await tester.pump(const Duration(milliseconds: 80));
    }

    await doubleTap(1100);
    await doubleTap(1100);
    expect(h.backend.calls.where((c) => c.startsWith('seek')).toList(), [
      'seek(610000)',
      'seek(610000)',
    ], reason: 'the fake backend does not move; each is +10 s');
    expect(h.container.read(osdProvider), '+20 s');

    await tester.pump(const Duration(seconds: 2));
    await doubleTap(100);
    expect(h.container.read(osdProvider), '−10 s');

    h.backend.calls.clear();
    await doubleTap(640);
    expect(h.backend.calls, ['pause']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hold for 2× while pressed', (tester) async {
    final h = await phone(tester);
    final finger = await tester.startGesture(const Offset(640, 360));
    await tester.pump(const Duration(milliseconds: 700));
    expect(h.service.state.rate, 2);
    await finger.up();
    await tester.pump();
    expect(h.service.state.rate, 1);
  });

  testWidgets('pinch zooms the picture', (tester) async {
    final h = await phone(tester);
    final a = await tester.startGesture(const Offset(540, 360), pointer: 1);
    final b = await tester.startGesture(const Offset(740, 360), pointer: 2);
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(Offset(540 - 10.0 * i, 360));
      await b.moveTo(Offset(740 + 10.0 * i, 360));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump();
    // Fingers 200 → 400 px apart; the recognizer starts after its slop,
    // so the scale is a bit more than 2× the starting span would give.
    expect(h.container.read(videoViewProvider).zoom, inInclusiveRange(1.4, 2));
  });

  testWidgets('switched-off gestures do nothing', (tester) async {
    final h = await phone(
      tester,
      prefs: {'gestureVolume': false, 'gestureDoubleTap': false},
    );
    await swipe(tester, x: 1000, dy: -288);
    expect(phoneVolume.value, 0.5);
    await tester.tapAt(const Offset(1100, 360));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(1100, 360));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backend.calls.where((c) => c.startsWith('seek')), isEmpty);
  });

  testWidgets('the lock hides the controls and blocks gestures', (
    tester,
  ) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('lock')));
    await tester.pump();
    expect(find.byKey(const Key('play-pause')), findsNothing);
    expect(find.byKey(const Key('unlock')), findsOneWidget);

    await swipe(tester, x: 1000, dy: -288);
    expect(phoneVolume.value, 0.5);

    await tester.tap(find.byKey(const Key('unlock')));
    await tester.pump();
    expect(find.byKey(const Key('play-pause')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
