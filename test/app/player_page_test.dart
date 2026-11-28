import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('idle start screen offers open file, paste and drop', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester);
    expect(find.text('OPEN MEDIA'), findsOneWidget);
    expect(find.byKey(const Key('open-file')), findsOneWidget);
    expect(find.textContaining('Or drop a file anywhere'), findsOneWidget);
    expect(find.byKey(const Key('play-pause')), findsNothing);
  });

  testWidgets('opens the launch file and shows the full control layout', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/v/The.Test.Film.2019.1080p.mkv'),
    );
    expect(
      h.backend.calls,
      contains('open(/v/The.Test.Film.2019.1080p.mkv, play: true)'),
    );
    h.load();
    await tester.pump();

    expect(find.text('The Test Film'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('1080P'), findsOneWidget);
    for (final key in [
      'top-back',
      'top-info',
      'mute',
      'volume-slider',
      'download',
      'skip-back',
      'play-pause',
      'skip-forward',
      'fit-button',
      'translate',
      'subtitles-button',
      'speed-button',
      'pip',
      'cast',
      'fullscreen',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('subtitle panel lists tracks and switches views', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();

    await tester.tap(find.byKey(const Key('subtitles-button')));
    await tester.pump();
    expect(find.byKey(const Key('subtitle-panel')), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Arabic'), findsWidgets);
    expect(find.text('PGS'), findsOneWidget);
    expect(find.text('Find more subtitles'), findsOneWidget);
    expect(find.text('Load file'), findsOneWidget);
    // No API key configured.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Add an OpenSubtitles API key'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sub-1')));
    await tester.pump();
    expect(h.backend.properties['sid'], '1');
    await tester.tap(find.byKey(const Key('sub-off')));
    await tester.pump();
    expect(h.backend.properties['sid'], 'no');
    await tester.tap(find.byKey(const Key('audio-2')));
    await tester.pump();
    expect(h.backend.properties['aid'], '2');

    await tester.tap(find.byKey(const Key('panel-sync')));
    await tester.pump();
    expect(find.text('SUBTITLE DELAY'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('sub-delay')),
        matching: find.byKey(const Key('delay-plus')),
      ),
    );
    await tester.pump();
    expect(h.backend.properties['sub-delay'], '0.100');

    await tester.tap(find.byKey(const Key('panel-style')));
    await tester.pump();
    expect(find.byKey(const Key('subtitle-preview')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('style-box')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('style-box')));
    await tester.pumpAndSettle();
    expect(h.backend.properties['sub-border-style'], 'opaque-box');

    await tester.tap(find.byKey(const Key('panel-close')));
    await tester.pump();
    expect(find.byKey(const Key('subtitle-panel')), findsNothing);
  });

  testWidgets('speed & sleep popover', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();

    await tester.tap(find.byKey(const Key('speed-button')));
    await tester.pump();
    expect(find.text('PLAYBACK SPEED'), findsOneWidget);
    expect(find.text('SLEEP TIMER'), findsOneWidget);
    expect(find.text('DEFAULT'), findsOneWidget);
    expect(find.text('End of next episode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('speed-1.25')));
    await tester.pump();
    expect(h.backend.calls, contains('rate(1.25)'));
    expect(find.text('1.25×'), findsWidgets);

    await tester.tap(find.byKey(const Key('sleep-30 min')));
    await tester.pump();
    expect(find.byKey(const Key('sleep-remaining')), findsOneWidget);
    // Selecting it again cancels.
    await tester.tap(find.byKey(const Key('sleep-30 min')));
    await tester.pump();
    expect(find.byKey(const Key('sleep-remaining')), findsNothing);
    await tester.tapAt(const Offset(200, 200)); // close popover
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('fit menu sets aspect, zoom and rotation', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    await tester.tap(find.byKey(const Key('fit-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fit-ratio4x3')));
    await tester.pump();
    expect(h.backend.properties['video-aspect-override'], '4:3');
    await tester.tap(find.byKey(const Key('zoom-in')));
    await tester.pump();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rotate')));
    await tester.pump();
    expect(h.backend.properties['video-rotate'], '90');
    await tester.tap(find.byKey(const Key('view-reset')));
    await tester.pump();
    expect(h.backend.properties['video-aspect-override'], 'no');
    expect(h.backend.properties['video-rotate'], '0');
  });

  testWidgets('keyboard shortcuts', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    h.backend.emitPosition(const Duration(minutes: 5));
    await tester.pump();
    h.backend.calls.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(h.backend.calls.last, 'pause');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(h.backend.calls.last, 'seek(310000)');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(h.backend.calls.last, 'seek(290000)');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(h.service.state.volume, 105);
    expect(
      tester.widget<Text>(find.byKey(const Key('volume-hud-value'))).data,
      '105%',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(h.service.state.volume, 100);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    expect(h.backend.properties['mute'], 'yes');
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    expect(h.backend.calls.last, 'rate(1.25)');
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    expect(h.backend.calls.last, 'rate(1.0)');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(h.window.isFullScreen, isTrue);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(h.container.read(subtitlePanelProvider), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(h.container.read(subtitlePanelProvider), isNull);
    expect(h.window.isFullScreen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(h.window.isFullScreen, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'controls auto-hide after 3 s of playback, mouse brings them back',
    (tester) async {
      final h = await AppHarness.create();
      await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
      h.load();
      await tester.pump();
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.byKey(const Key('play-pause')),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      expect(opacity(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(600, 300));
      await mouse.moveTo(const Offset(620, 310));
      await tester.pump();
      expect(opacity(), 1);

      // Paused: stays visible.
      h.backend.emitPlaying(value: false);
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(), 1);
    },
  );

  testWidgets('click toggles play, double-click toggles full screen', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    h.backend.calls.clear();
    await tester.tapAt(const Offset(640, 300), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backend.calls, ['pause']);

    await tester.tapAt(const Offset(640, 300), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(640, 300), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.window.isFullScreen, isTrue);
    expect(h.backend.calls, ['pause'], reason: 'double-click must not toggle');
  });

  testWidgets('scroll on the video changes the volume', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(640, 300));
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(640, 300),
        scrollDelta: Offset(0, -20),
      ),
    );
    await tester.pump();
    expect(h.service.state.volume, 105);
  });

  testWidgets('touch drag seeks on release', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    h.backend.emitPosition(const Duration(minutes: 10));
    await tester.pump();
    h.backend.calls.clear();
    final finger = await tester.startGesture(const Offset(300, 300));
    for (var i = 1; i <= 10; i++) {
      await finger.moveTo(Offset(300 + 64.0 * i, 300));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('osd')), findsOneWidget);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backend.calls.where((c) => c.startsWith('seek')), hasLength(1));
    final ms = int.parse(
      h.backend.calls
          .firstWhere((c) => c.startsWith('seek'))
          .substring(5)
          .replaceAll(')', ''),
    );
    expect(ms, closeTo(690000, 15000));
  });

  testWidgets('error shows the message and the mpv log excerpt', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/broken.avi'));
    h.backend
      ..emitLog('error', 'ffmpeg', 'Invalid data found when processing input')
      ..emitError('Failed to recognize file format.');
    await tester.pump();
    expect(find.text("Can't play this file"), findsOneWidget);
    expect(find.byKey(const Key('error-log')), findsOneWidget);
    expect(
      find.textContaining('Invalid data found when processing input'),
      findsOneWidget,
    );
  });

  testWidgets('back closes the file', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    await tester.tap(find.byKey(const Key('top-back')));
    await tester.pump();
    expect(h.service.state.status, PlaybackStatus.idle);
    expect(find.text('OPEN MEDIA'), findsOneWidget);
  });

  testWidgets('download: local files get a hint; web videos ask once', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    await tester.tap(find.byKey(const Key('download')));
    await tester.pump();
    expect(find.byKey(const Key('download-hint')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Download this video'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    await tester.tapAt(const Offset(600, 300));
    await tester.pump();

    await h.service.open('https://example.org/films/Clip.mp4');
    h.load();
    await tester.pump();
    await tester.tap(find.byKey(const Key('download')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('download-current')));
    await tester.pumpAndSettle();
    expect(find.text('Before you download'), findsOneWidget);
    await tester.tap(find.byKey(const Key('download-agree')));
    await tester.pump();
    expect(h.container.read(settingsProvider).downloadTermsAccepted, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('settings page: every section renders', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    // The window is frameless: the page brings its own buttons and drag area.
    expect(find.byKey(const Key('window-close')), findsOneWidget);
    expect(find.byKey(const Key('title-bar-drag-area')), findsOneWidget);
    for (final name in [
      'Playback', 'Subtitles', 'Audio', 'Video', 'Gestures', 'Shortcuts', //
      'Library',
      'Appearance', 'Language', 'Advanced', 'About',
    ]) {
      await tester.tap(find.byKey(Key('settings-section-$name')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
    }
  });

  testWidgets('a rebound shortcut works and the old key stops', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-section-Shortcuts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shortcut-edit-mute')));
    await tester.pump();
    expect(find.text('Press keys…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.text('K'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    expect(h.backend.properties['mute'], isNot('yes'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    expect(h.backend.properties['mute'], 'yes');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hide delay setting is used', (tester) async {
    final h = await AppHarness.create(prefs: {'controlsHideSeconds': 10});
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byKey(const Key('play-pause')),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    await tester.pump(const Duration(seconds: 5));
    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 6));
    expect(opacity(), 0);
  });
}
