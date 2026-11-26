import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/features/library/library_lists.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

/// Task 8.12: a 10 000-video folder stays light. Only the rows on screen
/// (plus a little) exist, the fast-scroller jumps anywhere at once, and
/// decoded pictures stay under the image cache's cap.
void main() {
  testWidgets('10 000 videos: few rows built, jumps are instant', (
    tester,
  ) async {
    final h = await AppHarness.create();
    h.scanner.files = [
      for (var i = 0; i < 10000; i++)
        ScannedFile(
          uri: '/m/Big/clip ${i.toString().padLeft(5, '0')}.mkv',
          name: 'clip ${i.toString().padLeft(5, '0')}.mkv',
          folderPath: '/m/Big',
          kind: MediaKind.video,
          size: 1000 + i,
          modified: DateTime(2026),
          added: DateTime(2026).add(Duration(minutes: i)),
          duration: const Duration(minutes: 20),
          width: 1920,
          height: 1080,
        ),
    ];
    await h.pump(tester, size: const Size(1280, 800));
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.videos);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-Big')));
    await tester.pumpAndSettle();

    int built() => find.byType(VideoTile).evaluate().length;
    expect(built(), lessThan(30), reason: 'only what is on screen');

    // Newest first: the fast-scroller's drag to the bottom reaches the
    // oldest at once.
    final strip = tester.getRect(find.byKey(const Key('fast-scroller')));
    final drag = await tester.startGesture(
      strip.topCenter + const Offset(0, 30),
    );
    await tester.pump();
    await drag.moveTo(strip.bottomCenter - const Offset(0, 2));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video-clip 00000.mkv')), findsOneWidget);
    expect(built(), lessThan(30));

    // Scrolling through a few screens never builds more.
    for (var i = 0; i < 5; i++) {
      await tester.fling(
        find.byKey(const Key('library-videos')),
        const Offset(0, 600),
        3000,
      );
      await tester.pumpAndSettle();
      expect(built(), lessThan(30));
    }
    expect(tester.takeException(), isNull);
    expect(
      PaintingBinding.instance.imageCache.currentSizeBytes,
      lessThanOrEqualTo(40 * 1024 * 1024),
    );
  });
}
