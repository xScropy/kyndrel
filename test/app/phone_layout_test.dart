import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

/// Task 6.5: the player on a phone.
void main() {
  const portrait = Size(392, 800);

  Future<AppHarness> phone(
    WidgetTester tester, {
    Size size = portrait,
    Map<String, Object> prefs = const {},
    int width = 1920,
    int height = 800,
  }) async {
    final h = await AppHarness.create(
      prefs: prefs,
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.phone,
        ),
      ],
    );
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/v/The.Test.Film.2019.1080p.mkv'),
      size: size,
    );
    h.load(width: width, height: height);
    await tester.pump();
    return h;
  }

  for (final (lang, shape, size) in [
    ('en', 'portrait', portrait),
    ('ar', 'portrait', portrait),
    ('en', 'landscape', const Size(800, 392)),
    ('ar', 'landscape', const Size(800, 392)),
  ]) {
    testWidgets('$shape layout fits ($lang)', (tester) async {
      await phone(tester, prefs: {'language': lang}, size: size);
      expect(tester.takeException(), isNull);
      for (final key in ['lock', 'subtitles-button', 'play-pause', 'more']) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      // Finger-sized controls.
      for (final key in ['lock', 'more']) {
        final box = tester.getSize(find.byKey(Key(key)));
        expect(box.height, greaterThanOrEqualTo(48), reason: key);
        expect(box.width, greaterThanOrEqualTo(48), reason: key);
      }
      // No volume slider on phones (swipe and volume keys instead).
      expect(find.byKey(const Key('volume-slider')), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/phone_${shape}_$lang.png'),
      );
    });
  }

  testWidgets('a small phone (320 dp) fits the bar too', (tester) async {
    // The emulator in CI caught an overflow here (48 dp buttons, 7.x).
    await phone(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    for (final key in ['lock', 'subtitles-button', 'play-pause', 'more']) {
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: key);
    }
  });

  testWidgets('"More" holds the other controls, and they still work', (
    tester,
  ) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-sheet')), findsOneWidget);
    for (final key in ['queue-button', 'fit-button', 'speed-button']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    await tester.tap(find.byKey(const Key('speed-button')));
    await tester.pumpAndSettle();
    expect(find.text('PLAYBACK SPEED'), findsOneWidget);
  });

  testWidgets('the subtitles panel fits a phone, tracks above details', (
    tester,
  ) async {
    final h = await phone(tester);
    h.container.read(subtitlePanelProvider.notifier).toggle();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byKey(const Key('subtitle-panel')));
    expect(panel.width, lessThanOrEqualTo(portrait.width - 16));
    expect(panel.left, greaterThanOrEqualTo(8));
  });

  testWidgets('immersive and turned to the video while it plays', (
    tester,
  ) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(call.arguments);
        }
        return null;
      },
    );
    // A tall (phone-shot) video: portrait, then the user turns it.
    final h = await phone(tester, width: 1080, height: 1920);
    await tester.pump();
    expect(h.window.isFullScreen, isTrue);
    expect(orientations.last, ['DeviceOrientation.portraitUp']);

    // The screen is portrait, so rotate turns it to landscape.
    await tester.tap(find.byKey(const Key('rotate')));
    await tester.pump();
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    // Back to the start screen: bars and free rotation return.
    await tester.tap(find.byKey(const Key('top-back')));
    await tester.pump();
    await tester.pump();
    expect(h.window.isFullScreen, isFalse);
    expect(orientations.last, isEmpty);
  });
}
