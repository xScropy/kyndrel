import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/settings_page.dart';
import 'package:kyndrel/core/platform/media_session.dart';
import 'package:kyndrel/core/platform/native_pip.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/pip/pip_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_platform_services.dart';

/// Task 6.6: what the phone does around the player.
void main() {
  late FakeNativePip pip;

  Future<AppHarness> phone(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    pip = FakeNativePip();
    final h = await AppHarness.create(
      prefs: prefs,
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.phone,
        ),
        nativePipProvider.overrideWithValue(pip),
      ],
    );
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/v/film.mkv'),
      size: const Size(800, 392),
    );
    h.load();
    h.backend.emitPlaying(value: true);
    await tester.pump();
    h.backend.calls.clear();
    return h;
  }

  Future<void> leaveApp(AppHarness h, WidgetTester tester) async {
    for (final c in h.window.hiddenCallbacks) {
      await c();
    }
    await tester.pump();
  }

  testWidgets('leaving the app pauses by default', (tester) async {
    final h = await phone(tester);
    await leaveApp(h, tester);
    expect(h.backend.calls, contains('pause'));
  });

  testWidgets('"Keep playing in the background" keeps the sound going', (
    tester,
  ) async {
    final h = await phone(tester, prefs: {'backgroundAudio': true});
    h.backend.properties['vid'] = '1';
    await leaveApp(h, tester);
    expect(h.backend.calls, isNot(contains('pause')));
    // Only the sound is decoded while nobody can see the picture (6.7).
    expect(h.backend.properties['vid'], 'no');

    for (final c in h.window.shownCallbacks) {
      await c();
    }
    expect(h.backend.properties['vid'], '1');
  });

  testWidgets("Android's PiP: auto-enter while playing, video only", (
    tester,
  ) async {
    final h = await phone(tester);
    final last = pip.configured.last;
    expect(last.auto, isTrue);
    expect(last.playing, isTrue);
    expect(last.aspect, closeTo(2.4, 0.01));
    // From the More sheet.
    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pip')));
    await tester.pump();
    expect(pip.entered, hasLength(1));

    pip.report(inPip: true);
    await tester.pumpAndSettle();
    expect(h.container.read(pipProvider), isTrue);
    expect(find.byKey(const Key('play-pause')), findsNothing);
    expect(find.byKey(const Key('pip-surface')), findsNothing);

    // Still playing in PiP, so going "away" doesn't pause it.
    await leaveApp(h, tester);
    expect(h.backend.calls, isNot(contains('pause')));

    pip.report(inPip: false);
    await tester.pump();
    await tester.pump();
    expect(h.container.read(pipProvider), isFalse);
    expect(find.byKey(const Key('play-pause')), findsOneWidget);

    // Paused: no auto-enter.
    h.backend.emitPlaying(value: false);
    await tester.pump();
    expect(pip.configured.last.auto, isFalse);
  });

  testWidgets('the auto-PiP setting turns it off', (tester) async {
    await phone(tester, prefs: {'autoPip': false});
    expect(pip.configured.last.auto, isFalse);
  });

  testWidgets('the phone settings are in Settings › Gestures', (tester) async {
    final h = await AppHarness.create(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.phone,
        ),
      ],
    );
    await h.pumpWidget(
      tester,
      const SettingsPage(),
      size: const Size(392, 800),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('settings-section-Gestures')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings-background-audio'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/phone_settings.png'),
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(h.container.read(settingsProvider).backgroundAudio, isTrue);

    // Back returns to the section list.
    await tester.tap(find.byKey(const Key('settings-back-to-sections')));
    await tester.pump();
    expect(find.byKey(const Key('settings-section-Audio')), findsOneWidget);
    expect(toggle, findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('notification buttons arrive as media commands', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('kyndrel/media_session');
    final session = ChannelMediaSession(channel);
    final got = <MediaCommand>[];
    final sub = session.commands.listen(got.add);
    Future<void> send(String method, [Object? args]) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(MethodCall(method, args)),
              (_) {},
            );
    await send('playPause');
    await send('seekBy', -10000);
    await send('seekTo', 65000);
    await Future<void>.delayed(Duration.zero);
    expect(got[0], isA<PlayPauseCommand>());
    expect((got[1] as SeekByCommand).offset, const Duration(seconds: -10));
    expect((got[2] as SeekToCommand).position, const Duration(seconds: 65));
    await sub.cancel();
    await session.dispose();
  });
}
