import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/features/speed_sleep/sleep_timer.dart';
import 'package:kyndrel/features/speed_sleep/speed_sleep_button.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('speed & sleep panel golden', (tester) async {
    final h = await AppHarness.create();
    await h.pumpWidget(
      tester,
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Popover(
            anchorBuilder: (_, _) => const SizedBox.shrink(),
            contentBuilder: (_, _) => const SpeedSleepPanel(),
          ),
        ),
      ),
      size: const Size(560, 560),
    );
    await tester.pumpWidget(const SizedBox()); // reset
    await h.pumpWidget(
      tester,
      const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xCC1A1A1F)),
          child: Padding(padding: EdgeInsets.all(16), child: SpeedSleepPanel()),
        ),
      ),
      size: const Size(560, 560),
    );
    await h.service.setRate(1.25);
    await h.container
        .read(sleepTimerProvider.notifier)
        .select(const SleepAfter(Duration(minutes: 45)));
    await tester.pump();
    await expectLater(
      find.byType(SpeedSleepPanel),
      matchesGoldenFile('goldens/speed_sleep_panel.png'),
    );
    await h.container.read(sleepTimerProvider.notifier).cancel();
  });

  testWidgets('subtitle panel golden', (tester) async {
    final h = await AppHarness.create();
    await h.service.open('/v/Film.mkv');
    h.load();
    await h.pumpWidget(
      tester,
      const Center(child: SubtitlePanel()),
      size: const Size(720, 480),
    );
    h.container.read(subtitlePanelProvider.notifier).open();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.textContaining('OpenSubtitles API key'), findsOneWidget);
    await expectLater(
      find.byType(SubtitlePanel),
      matchesGoldenFile('goldens/subtitle_panel.png'),
    );
  });
}
