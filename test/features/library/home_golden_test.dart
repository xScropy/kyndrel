import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

/// Task 9.16: Harbor's home, with something to pick up again.
void main() {
  for (final (name, size) in [
    ('desktop_en', const Size(1280, 800)),
    ('phone_en', const Size(392, 800)),
  ]) {
    testWidgets('home looks right: $name', (tester) async {
      final h = await AppHarness.create();
      final repo = HistoryRepository(h.db);
      await tester.runAsync(() async {
        for (final (i, f) in [
          'The.Last.Voyage.2024.mkv',
          'Night.Train.S01E03.mkv',
          'Harbour.Lights.2019.mkv',
        ].indexed) {
          await repo.record(
            source: '/v/$f',
            title: f.split('.').take(3).join(' '),
            position: Duration(minutes: 20 + i * 10),
            duration: const Duration(hours: 1),
          );
        }
      });
      await h.pump(tester, size: size);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$name.png'),
      );
    });
  }
}
