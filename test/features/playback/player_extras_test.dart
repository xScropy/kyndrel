import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/features/playback/clip_export.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 8.8: subtitle lines, quick commands, mouse buttons, clip export,
/// swipe for the next file.
void main() {
  test('quick commands: label, then arguments (quotes keep spaces)', () {
    final c = parseQuickCommands([
      'Night | set brightness 10',
      'Shot | screenshot-to-file "/tmp/my shot.png" video',
      'no bar here',
      '| empty label',
      'Empty |',
    ]);
    expect(c.map((x) => x.label), ['Night', 'Shot']);
    expect(c[0].args, ['set', 'brightness', '10']);
    expect(c[1].args, ['screenshot-to-file', '/tmp/my shot.png', 'video']);
  });

  test('clip export: stream copy, or a GIF with its own palette', () {
    final clip = ClipExport.argsFor(
      source: '/v/a.mkv',
      a: const Duration(seconds: 61, milliseconds: 500),
      b: const Duration(seconds: 70),
      out: '/o/a.mkv',
      gif: false,
    );
    expect(clip.take(7), [
      '-y',
      '-ss',
      '61.500',
      '-to',
      '70.000',
      '-i',
      '/v/a.mkv',
    ]);
    expect(clip, containsAllInOrder(['-c', 'copy', '/o/a.mkv']));
    final gif = ClipExport.argsFor(
      source: '/v/a.mkv',
      a: Duration.zero,
      b: const Duration(seconds: 3),
      out: '/o/a.gif',
      gif: true,
    );
    expect(gif, contains(ClipExport.gifFilter));
    expect(gif.last, '/o/a.gif');
  });

  test('a real GIF from the test clip (when ffmpeg is here)', () async {
    final clip = p.absolute('test_media/generated/clip.mp4');
    if (!File(clip).existsSync() || !await ClipExport.available()) {
      markTestSkipped('needs ffmpeg and scripts/make_test_media.sh');
      return;
    }
    final out = p.join(
      Directory.systemTemp.createTempSync('kyndrel_gif').path,
      'c.gif',
    );
    final r = await Process.run(
      'ffmpeg',
      ClipExport.argsFor(
        source: clip,
        a: const Duration(seconds: 1),
        b: const Duration(seconds: 2),
        out: out,
        gif: true,
      ),
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(File(out).readAsBytesSync().sublist(0, 3), 'GIF'.codeUnits);
  });

  Future<AppHarness> playing(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool phone = false,
  }) async {
    final h = await AppHarness.create(
      prefs: prefs,
      overrides: [
        if (phone)
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.phone,
          ),
      ],
    );
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/v/film.mkv'),
      size: phone ? const Size(392, 800) : const Size(1280, 720),
    );
    h.load();
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+T lists the subtitle file; a tap jumps to the line', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_lines');
    addTearDown(() => dir.deleteSync(recursive: true));
    final srt = File(p.join(dir.path, 'film.srt'))
      ..writeAsStringSync(
        '1\n00:00:01,000 --> 00:00:02,000\nHello\n\n'
        '2\n00:01:00,000 --> 00:01:05,000\nGeneral Kenobi\n',
      );
    final h = await playing(tester);
    h.backend.emitTracks([
      {'id': '1', 'type': 'video', 'codec': 'h264'},
      {
        'id': '3',
        'type': 'sub',
        'codec': 'subrip',
        'external': 'yes',
        'external-filename': srt.path,
      },
    ]);
    await h.service.selectSubtitle(3);
    h.backend.emitPosition(const Duration(seconds: 62));
    await tester.pump();
    await ctrl(tester, LogicalKeyboardKey.keyT);
    expect(find.text('General Kenobi'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('line-1'))).selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('line-0')));
    await tester.pump();
    expect(h.backend.calls.last, 'seek(1000)');
  });

  testWidgets('Ctrl+K runs a quick command', (tester) async {
    final h = await playing(
      tester,
      prefs: {
        'customCommands': ['Night | set brightness 10'],
      },
    );
    await ctrl(tester, LogicalKeyboardKey.keyK);
    await tester.tap(find.byKey(const Key('quick-Night')));
    await tester.pumpAndSettle();
    expect(h.backend.commands.last, ['set', 'brightness', '10']);
  });

  testWidgets('mouse: middle plays/pauses, back seeks back', (tester) async {
    final h = await playing(tester);
    final center = tester.getCenter(find.byKey(const Key('video-layer')));
    final middle = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await middle.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backend.calls, contains('pause'));
    final back = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await back.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.backend.calls.where((c) => c.startsWith('seek(')), isNotEmpty);
  });

  testWidgets('phones: fling the buttons sideways for the next file', (
    tester,
  ) async {
    final h = await playing(tester, phone: true);
    await h.container.read(playlistProvider.notifier).openAll([
      '/v/1.mkv',
      '/v/2.mkv',
    ]);
    h.load();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.fling(
      find.byKey(const Key('swipe-next')),
      const Offset(-200, 0),
      1500,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.container.read(playlistProvider).current, 1);
  });
}
