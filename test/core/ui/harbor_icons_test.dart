import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/ui/harbor_icon.dart';
import 'package:kyndrel/core/ui/harbor_icons.g.dart';
import 'package:material_ui/material_ui.dart';

/// Task 9.2: Harbor's player icons, painted from their SVG paths.
void main() {
  const icons = [
    HarborIcons.back,
    HarborIcons.seekBack,
    HarborIcons.playPausePlaying,
    HarborIcons.playPausePaused,
    HarborIcons.seekForward,
    HarborIcons.prevEpisode,
    HarborIcons.nextEpisode,
    HarborIcons.volume,
    HarborIcons.volumeMute,
    HarborIcons.downloadIdle,
    HarborIcons.audio,
    HarborIcons.subtitle,
    HarborIcons.speed,
    HarborIcons.aspect,
    HarborIcons.anime4k,
    HarborIcons.pipActive,
    HarborIcons.castIdle,
    HarborIcons.fullscreenFullscreen,
    HarborIcons.fullscreenWindowed,
    HarborIcons.screenshot,
    HarborIcons.dvrRecording,
  ];

  testWidgets('every icon parses and paints', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 140));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF0B0B0D),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final i in icons)
                HarborIcon(i, size: 32, color: const Color(0xFFFFFFFF)),
            ],
          ),
        ),
      ),
    );
    for (final i in icons) {
      expect(i.path.getBounds().isEmpty, isFalse);
    }
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/harbor_icons.png'),
    );
  });
}
