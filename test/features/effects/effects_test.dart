import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/features/effects/effects_dialog.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_player_backend.dart';

void main() {
  test('equalizer graph: one band per non-zero gain, null when flat', () {
    expect(Equalizer.filter(Equalizer.presets['Flat']!), isNull);
    expect(
      Equalizer.filter([6, 0, 0, 0, 0, 0, 0, 0, 0, -2.5]),
      'equalizer=f=31:t=o:w=1:g=6.0,equalizer=f=16000:t=o:w=1:g=-2.5',
    );
    expect(Equalizer.presetName(Equalizer.presets['Voice']!), 'Voice');
    expect(Equalizer.presetName([1, 0, 0, 0, 0, 0, 0, 0, 0, 0]), isNull);
  });

  test('audio filters are labelled and replaced, not stacked', () async {
    final b = FakePlayerBackend();
    final s = PlayerService(b);
    addTearDown(s.dispose);
    await s.setEqualizer(Equalizer.presets['Bass boost']!);
    await s.setEqualizer(Equalizer.presets['Bass boost']!); // no-op
    await s.setEqualizer(Equalizer.presets['Rock']!);
    await s.setNormalization(Normalization.loudnorm);
    await s.setEqualizer(Equalizer.presets['Flat']!);
    expect(b.commands.map((c) => '${c[1]} ${c[2].split(':').first}'), [
      'add @kyndrel-eq',
      'remove @kyndrel-eq',
      'add @kyndrel-eq',
      'add @kyndrel-norm',
      'remove @kyndrel-eq',
    ]);
    expect(b.commands[3][2], contains('loudnorm=I=-16'));
  });

  test('video preset options and shader', () async {
    final b = FakePlayerBackend();
    final s = PlayerService(b);
    addTearDown(s.dispose);
    await s.applyVideoPreset(
      VideoPreset.sharpen,
      shaderPath: '/c/sharpen.glsl',
    );
    expect(b.properties['scale'], 'ewa_lanczossharp');
    expect(b.properties['glsl-shaders'], '/c/sharpen.glsl');
    await s.applyVideoPreset(VideoPreset.fast, shaderPath: '/c/sharpen.glsl');
    expect(b.properties['scale'], 'bilinear');
    expect(b.properties['glsl-shaders'], '');
    await s.setToneMapping('hable');
    await s.setHardwareDecoding('no');
    await s.setDeband(enabled: true);
    expect(b.properties['tone-mapping'], 'hable');
    expect(b.properties['hwdec'], 'no');
    expect(b.properties['deband'], 'yes');
  });

  testWidgets('dialog changes reach the engine', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    final context = tester.element(find.byType(Scaffold).first);
    unawaitedDialog(context);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preset-highQuality')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deband')));
    await tester.pump();
    expect(h.backend.properties['scale'], 'ewa_lanczossharp');
    expect(h.backend.properties['deband'], 'yes');

    await tester.tap(find.byKey(const Key('tab-audio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eq-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinema').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('norm-dynamic')));
    await tester.pump();
    final af = h.backend.commands.where((c) => c.first == 'af').toList();
    expect(af.any((c) => c[2].contains('equalizer=f=31')), isTrue);
    expect(af.last[2], contains('dynaudnorm'));
  });
}

void unawaitedDialog(BuildContext context) {
  // ignore: discarded_futures, the test drives the dialog itself
  showEffectsDialog(context);
}
