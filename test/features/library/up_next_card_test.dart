import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/playlist/up_next.dart';
import 'package:kyndrel/features/library/up_next_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('shows the next episode with a countdown and Play now', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pumpWidget(
      tester,
      const Center(child: UpNextCard()),
      size: const Size(500, 300),
    );
    expect(find.byKey(const Key('up-next')), findsNothing);

    final queue = h.container.read(playlistProvider.notifier);
    await queue.openAll(['/tv/Show.S01E01.mkv', '/tv/Show.S01E02.mkv']);
    h.container
        .read(upNextProvider.notifier)
        .start(index: 1, source: '/tv/Show.S01E02.mkv', seconds: 10);
    await tester.pump();
    expect(find.text('Show · S01E02'), findsOneWidget);
    expect(find.text('Playing in 10 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Playing in 7 s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('up-next-play')));
    await tester.pump();
    expect(find.byKey(const Key('up-next')), findsNothing);
    expect(h.backend.calls.last, contains('Show.S01E02.mkv'));
  });
}
