import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/seek_bar_painter.dart';
import 'package:material_ui/material_ui.dart';

/// Task 9.3: Harbor's seek bar looks.
void main() {
  test('the look comes from settings', () {
    const s = AppSettings(
      seekBarStyle: SeekBarStyle.rainbow,
      seekBarHeight: 9,
      seekBarColor: 0xFF3B82F6,
      seekDotShape: SeekDotShape.square,
      seekDotSize: 20,
      seekDotOnHover: false,
    );
    final look = SeekBarLook.fromSettings(s);
    expect(look.style, SeekBarStyle.rainbow);
    expect(look.height, 9);
    expect(look.color, const Color(0xFF3B82F6));
    expect(look, SeekBarLook.fromSettings(s));
    expect(
      const AppSettings().seekBarColor,
      KyndrelColors.seekAmber.toARGB32(),
    );
  });

  testWidgets('flat, glass, pinstripe, rainbow; square and hidden thumbs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget bar(SeekBarLook look, {bool hovering = true}) => SizedBox(
      width: double.infinity,
      height: 40,
      child: CustomPaint(
        painter: SeekBarPainter(
          progress: 0.55,
          buffered: 0.75,
          hovering: hovering,
          look: look,
          marks: const [0.3],
        ),
      ),
    );
    await tester.pumpWidget(
      ColoredBox(
        color: KyndrelColors.background,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            key: const Key('looks'),
            children: [
              bar(const SeekBarLook()),
              bar(const SeekBarLook(style: SeekBarStyle.glass, height: 10)),
              bar(
                const SeekBarLook(
                  style: SeekBarStyle.pinstripe,
                  height: 12,
                  color: KyndrelColors.accent,
                  dotShape: SeekDotShape.square,
                ),
              ),
              bar(const SeekBarLook(style: SeekBarStyle.rainbow, height: 12)),
              // At rest the thumb waits for the pointer.
              bar(const SeekBarLook(), hovering: false),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('looks')),
      matchesGoldenFile('goldens/seek_bar_looks.png'),
    );
  });
}
