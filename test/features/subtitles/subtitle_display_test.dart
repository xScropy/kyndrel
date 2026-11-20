import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/device_media.dart';
import 'package:kyndrel/core/player/subtitle_fonts.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_media.dart';

/// Task 7.1: a chosen subtitle track must show, or say why not.
void main() {
  Future<AppHarness> withPanel(
    WidgetTester tester, {
    FakeDeviceMedia? device,
  }) async {
    final h = await AppHarness.create(
      overrides: [
        if (device != null) deviceMediaProvider.overrideWithValue(device),
      ],
    );
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    h.container.read(subtitlePanelProvider.notifier).open();
    await tester.pump();
    return h;
  }

  testWidgets('choosing a track also makes subtitles visible', (tester) async {
    final h = await withPanel(tester);
    h.backend.properties['sub-visibility'] = 'no';
    await tester.tap(find.byKey(const Key('sub-1')));
    await tester.pump();
    expect(h.backend.properties['sid'], '1');
    expect(h.backend.properties['sub-visibility'], 'yes');
  });

  testWidgets('the second line moves to the main one instead of failing', (
    tester,
  ) async {
    final h = await withPanel(tester);
    h.backend.emitProperty('secondary-sid', '2');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sub-2')));
    await tester.pump();
    expect(h.backend.properties['secondary-sid'], 'no');
    expect(h.backend.properties['sid'], '2');
  });

  testWidgets("a track mpv won't take is reported on screen", (tester) async {
    final h = await withPanel(tester);
    h.backend.refused.add('sid');
    await tester.tap(find.byKey(const Key('sub-2')));
    await tester.pump();
    await tester.pump();
    expect(h.container.read(osdProvider), "This subtitle track can't be shown");
  });

  testWidgets('the secondary choices leave out the main track', (tester) async {
    final h = await withPanel(tester);
    await tester.tap(find.byKey(const Key('sub-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('panel-sync')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('secondary-sid')));
    await tester.pumpAndSettle();
    // English (1) is the main track: only Arabic is offered.
    expect(find.text('English').hitTestable(), findsNothing);
    expect(find.text('Arabic').hitTestable(), findsWidgets);
    expect(h.backend.properties['sid'], '1');
  });

  testWidgets("Android: 'Load file' uses the phone's picker and a local copy", (
    tester,
  ) async {
    final device = FakeDeviceMedia()
      ..pickedCopy = '/data/cache/picked/Film.ar.srt';
    final h = await withPanel(tester, device: device);
    await tester.tap(find.text('Load file'));
    await tester.pump();
    expect(h.backend.commands.last, [
      'sub-add',
      '/data/cache/picked/Film.ar.srt',
      'select',
    ]);
  });

  test('subtitle fonts are copied once for libass', () async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_fonts');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bundle = _Bundle();
    final path = await SubtitleFonts.prepare(dir, bundle: bundle);
    expect(
      Directory(path).listSync().map((f) => f.uri.pathSegments.last).toSet(),
      {'Inter.ttf', 'NotoSansArabic.ttf'},
    );
    final stamp = File('$path/Inter.ttf').lastModifiedSync();
    await SubtitleFonts.prepare(dir, bundle: bundle);
    expect(File('$path/Inter.ttf').lastModifiedSync(), stamp);
  });
}

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode('font:$key')));
}
