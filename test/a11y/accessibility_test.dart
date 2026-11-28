import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

/// The `ValueKey<String>` of the widget holding keyboard focus.
String? _focusedKey() {
  String? key;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) key = k.value;
    return key == null;
  });
  return key;
}

Future<AppHarness> _loaded(WidgetTester tester, {String? language}) async {
  final h = await AppHarness.create(prefs: {'language': ?language});
  await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
  h.load();
  await tester.pump();
  return h;
}

void main() {
  group('guidelines (task 5.3)', () {
    for (final language in ['en', 'ar']) {
      testWidgets('player page meets labels and contrast ($language)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _loaded(tester, language: language);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('start screen meets labels and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await AppHarness.create();
      await h.pump(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('settings page meets labels and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await AppHarness.create();
      await h.pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-section-Playback')), findsOne);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  testWidgets('Tab walks the controls top to bottom, start to end', (
    tester,
  ) async {
    await _loaded(tester);
    final order = <String?>[];
    for (var i = 0; i < 17; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      order.add(_focusedKey());
    }
    expect(order, [
      'top-back',
      'decoder-button',
      'top-info',
      // Harbor's "Up next" tab, halfway down the right edge (task 9.2).
      'queue-button',
      'seek-total',
      'mute',
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
    ]);
    await tester.pump(ControlsVisibility.hideDelay);
  });

  testWidgets('keyboard focus keeps the controls up; the mouse releases', (
    tester,
  ) async {
    final h = await _loaded(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(ControlsVisibility.hideDelay * 3);
    expect(h.container.read(controlsVisibilityProvider), isTrue);

    final visibility = h.container.read(controlsVisibilityProvider.notifier);
    expect(visibility.isLocked, isTrue);
    // A click puts Flutter back in pointer highlight mode (on the video it
    // also toggles playback; resume so auto-hide applies again).
    await tester.tapAt(const Offset(640, 300), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(visibility.isLocked, isFalse);
    h.backend.emitPlaying(value: true);
    await tester.pump(ControlsVisibility.hideDelay * 2);
    expect(h.container.read(controlsVisibilityProvider), isFalse);
  });

  testWidgets('screen readers can seek with the slider actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await _loaded(tester);
    final node = tester.getSemantics(find.byKey(const Key('seek-bar')));
    expect(node.label, 'Seek');
    expect(node.value, '0:00 of 1:00:00');
    expect(node.increasedValue, '0:10 of 1:00:00');

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(h.backend.calls.last, 'seek(10000)');
    handle.dispose();
  });

  testWidgets('every control button announces its action', (tester) async {
    final handle = tester.ensureSemantics();
    await _loaded(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('play-pause'))),
      matchesSemantics(
        label: 'Pause',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('video-gestures'))).hint,
      contains('double-tap'),
    );
    handle.dispose();
  });
}
