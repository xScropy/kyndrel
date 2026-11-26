import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/file_settings_repository.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/effects/effects_dialog.dart';
import 'package:kyndrel/features/playback/file_settings_controller.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 8.8: per-file settings, incognito, picture adjustments, long-press
/// speed slide, ZIP subtitles, pure black.
void main() {
  Future<AppHarness> open(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    final h = await AppHarness.create(prefs: prefs);
    await h.pump(tester, launch: const LaunchOptions(source: '/v/a.mkv'));
    h.load();
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  Future<PerFileSettings?> saved(WidgetTester tester, AppHarness h) =>
      tester.runAsync<PerFileSettings?>(
        () => FileSettingsRepository(h.db).get('/v/a.mkv'),
      );

  testWidgets('a file remembers its tracks, speed and delays', (tester) async {
    final h = await open(tester);
    await h.service.selectAudioTrack(2);
    await h.service.setRate(1.5);
    await h.service.setSubtitleDelay(const Duration(milliseconds: 300));
    await tester.pump(FileSettingsController.saveDelay * 2);
    final s = (await saved(tester, h))!;
    expect((s.audioId, s.rate), (2, 1.5));
    expect(s.subtitleDelay, const Duration(milliseconds: 300));

    // Another file, then this one again: its settings come back.
    await h.service.open('/v/b.mkv');
    h.load();
    await tester.pump(const Duration(milliseconds: 100));
    await h.service.setRate(1);
    await h.service.selectAudioTrack(1);
    await h.service.open('/v/a.mkv');
    h.load();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.backend.properties['aid'], '2');
    expect(h.service.state.rate, 1.5);
    expect(h.backend.properties['sub-delay'], startsWith('0.3'));
  });

  testWidgets('incognito: no file settings, no resume point', (tester) async {
    final h = await open(tester, prefs: {'incognito': true});
    await h.service.setRate(1.25);
    await tester.pump(FileSettingsController.saveDelay * 2);
    expect(await saved(tester, h), isNull);
    h.backend
      ..emitPosition(const Duration(minutes: 20))
      ..emitPlaying(value: false);
    await tester.pump(const Duration(milliseconds: 200));
    final point = await tester.runAsync(
      () => h.container.read(resumeRepositoryProvider).get('/v/a.mkv'),
    );
    expect(point, isNull);
  });

  testWidgets('picture adjustments reach mpv; reset clears them', (
    tester,
  ) async {
    final h = await open(tester);
    final c = h.container.read(pictureAdjustmentsProvider.notifier);
    await c.set('brightness', 20);
    await c.set('saturation', -150);
    expect(h.backend.properties['brightness'], '20');
    expect(h.backend.properties['saturation'], '-100', reason: 'clamped');
    await c.reset();
    expect(h.backend.properties['brightness'], '0');
    expect(h.container.read(pictureAdjustmentsProvider), isEmpty);
  });

  testWidgets('hold for 2×, slide sideways for more, let go for normal', (
    tester,
  ) async {
    final h = await open(tester);
    final center = tester.getCenter(find.byKey(const Key('video-layer')));
    final g = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(h.service.state.rate, 2);
    await g.moveBy(const Offset(85, 0));
    await tester.pump();
    expect(h.service.state.rate, 2.5);
    await g.moveBy(const Offset(-400, 0));
    await tester.pump();
    expect(h.service.state.rate, 1, reason: 'no slower than 1×');
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(h.service.state.rate, 1);
  });

  test('subtitles inside a ZIP are unpacked', () {
    final dir = Directory.systemTemp.createTempSync('kyndrel_zip');
    addTearDown(() => dir.deleteSync(recursive: true));
    final srt = '1\n00:00:01,000 --> 00:00:02,000\nHello\n'.codeUnits;
    final archive = Archive()
      ..addFile(ArchiveFile('subs/Film.en.srt', srt.length, srt))
      ..addFile(ArchiveFile('readme.txt', 2, 'hi'.codeUnits));
    final zip = File(p.join(dir.path, 'subs.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    final out = SubtitleFileActions.unzipSubtitles(
      zip.path,
      p.join(dir.path, 'out'),
    );
    expect(out.map(p.basename), ['Film.en.srt']);
    expect(File(out.single).readAsStringSync(), contains('Hello'));
  });

  test('pure black', () {
    expect(
      KyndrelTheme.dark(black: true).scaffoldBackgroundColor,
      KyndrelColors.black,
    );
    expect(
      KyndrelTheme.dark().scaffoldBackgroundColor,
      KyndrelColors.background,
    );
    expect(const AppSettings().amoledBlack, isFalse);
  });
}
