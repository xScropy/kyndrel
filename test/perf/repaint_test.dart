import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/features/playback/widgets/bottom_controls.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

/// The boundary's recorded content. Repainting a boundary records new
/// picture layers, so an identical list means its pixels were reused.
/// (`debugAsymmetricPaintCount` also counts frames where only the parent
/// painted, so it can't tell the two apart.)
List<Layer> _layers(WidgetTester tester, Finder boundary) {
  final r = tester.renderObject<RenderRepaintBoundary>(boundary);
  final out = <Layer>[];
  void walk(Layer? l) {
    for (var c = l; c != null; c = c.nextSibling) {
      out.add(c);
      // A plain OffsetLayer is a nested RepaintBoundary: its content is
      // its own business.
      if (c is ContainerLayer && c.runtimeType != OffsetLayer) {
        walk(c.firstChild);
      }
    }
  }

  walk(r.debugLayer!.firstChild);
  return out;
}

Matcher _same(List<Layer> before) =>
    pairwiseCompare<Layer, Layer>(before, identical, 'is the same layer as');

Finder _boundaryAbove(Type widget) => find
    .ancestor(of: find.byType(widget), matching: find.byType(RepaintBoundary))
    .first;

/// Task 5.4: what repaints while a film plays and the overlay animates.
void main() {
  testWidgets('position ticks repaint only the seek bar', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    // Let the play/pause icon morph finish and the first position arrive
    // before taking the baseline.
    h.backend.emitPosition(Duration.zero);
    await tester.pump(const Duration(milliseconds: 500));

    final video = find.byKey(const Key('video-layer'));
    final bar = _boundaryAbove(BottomControls);
    final seek = _boundaryAbove(SeekBarRow);
    final v0 = _layers(tester, video);
    final b0 = _layers(tester, bar);
    final s0 = _layers(tester, seek);

    for (var i = 1; i <= 20; i++) {
      h.backend.emitPosition(Duration(milliseconds: 250 * i));
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(_layers(tester, video), _same(v0), reason: 'video repainted');
    expect(_layers(tester, bar), _same(b0), reason: 'bottom bar repainted');
    expect(_layers(tester, seek), isNot(_same(s0)), reason: 'seek bar idle');
    await tester.pump(ControlsVisibility.hideDelay);
  });

  testWidgets('the overlay fade never repaints the video or the controls', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    // Let the play/pause icon morph finish before taking the baseline.
    await tester.pump(const Duration(milliseconds: 500));
    final video = find.byKey(const Key('video-layer'));
    final bar = _boundaryAbove(BottomControls);
    final v0 = _layers(tester, video);
    final b0 = _layers(tester, bar);

    // Let the controls hide, frame by frame through the 200 ms fade.
    await tester.pump(ControlsVisibility.hideDelay);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(h.container.read(controlsVisibilityProvider), isFalse);

    expect(_layers(tester, video), _same(v0));
    // Opacity is composited; the controls' own pixels are reused.
    expect(_layers(tester, bar), _same(b0));
  });
}
