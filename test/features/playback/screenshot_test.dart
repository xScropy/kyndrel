import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/playback/screenshot_actions.dart';

import '../../support/app_harness.dart';

void main() {
  test('default folder', () {
    expect(
      defaultScreenshotFolder({'HOME': '/home/me'}),
      '/home/me/Pictures/Kyndrel',
    );
  });

  test('file name from title, episode and time', () {
    expect(
      ScreenshotActions.fileName(
        '/v/Show.S01E02.mkv',
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      'Show S01E02 01-02-03.png',
    );
    expect(
      ScreenshotActions.fileName('/v/a:b?.mkv', Duration.zero),
      'a_b_ 00-00-00.png',
    );
  });

  testWidgets('Ctrl+S saves to the configured folder', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_shot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final h = await AppHarness.create(
      prefs: {'screenshotFolder': dir.path, 'screenshotWithSubtitles': true},
    );
    await h.pump(tester);
    await h.service.open('/v/Film.2019.mkv');
    h.load();
    h.backend.emitPosition(const Duration(minutes: 1, seconds: 5));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final cmd = h.backend.commands.lastWhere(
      (c) => c.first == 'screenshot-to-file',
    );
    expect(cmd[1], '${dir.path}/Film 00-01-05.png');
    expect(cmd[2], 'subtitles');
    expect(find.textContaining('Screenshot saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
