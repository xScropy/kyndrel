import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/features/pip/pip_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
  Future<AppHarness> playing(WidgetTester tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    await tester.pump();
    h.load(); // 1920×800
    await tester.pump();
    return h;
  }

  testWidgets('PiP shrinks to an aspect-locked, on-top corner window and '
      'restores the old bounds', (tester) async {
    final h = await playing(tester);
    await tester.tap(find.byKey(const Key('pip')));
    await tester.pump();
    expect(h.container.read(pipProvider), isTrue);
    expect(h.window.alwaysOnTop, isTrue);
    expect(h.window.aspectRatio, closeTo(1920 / 800, 0.001));
    expect(h.window.bounds.width, PipController.width);
    expect(h.window.bounds.height, 167);
    expect(h.window.bounds.right, 1920 - PipController.margin);
    expect(h.window.bounds.bottom, 1040 - PipController.margin);
    expect(find.byKey(const Key('pip-surface')), findsOneWidget);
    expect(find.byKey(const Key('play-pause')), findsNothing);
    expect(
      h.backend.calls.where((c) => c.startsWith('open')),
      hasLength(1),
      reason: 'same player, no restart',
    );

    await tester.tap(find.byKey(const Key('pip-surface')));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byKey(const Key('pip-surface')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.container.read(pipProvider), isFalse);
    expect(h.window.bounds, const Rect.fromLTWH(100, 100, 1280, 720));
    expect(h.window.alwaysOnTop, isFalse);
    expect(h.window.aspectRatio, 0);
    expect(h.window.minimumSize, PipController.normalMinimum);
  });

  testWidgets('from full screen, I enters PiP and Esc goes back to full '
      'screen', (tester) async {
    final h = await playing(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(h.window.isFullScreen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(h.container.read(pipProvider), isTrue);
    expect(h.window.isFullScreen, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(h.container.read(pipProvider), isFalse);
    expect(h.window.isFullScreen, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hover shows play/pause and restore', (tester) async {
    final h = await playing(tester);
    await h.container.read(pipProvider.notifier).enter();
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(300, 300));
    await tester.pumpAndSettle();
    h.backend.calls.clear();
    await tester.tap(find.byKey(const Key('pip-play')));
    expect(h.backend.calls, ['pause']);
    await tester.tap(find.byKey(const Key('pip-restore')));
    await tester.pump();
    expect(h.container.read(pipProvider), isFalse);
  });
}
