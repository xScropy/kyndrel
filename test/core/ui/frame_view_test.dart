import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/tiny_jpeg.dart';

/// Tasks 8.2–8.3: showing storyboard cells and exact frames.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kyndrel_fv'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('a cell at once from the cache; the exact frame fades in', (
    tester,
  ) async {
    final sheet = File(p.join(tmp.path, 's0.jpg'))
      ..writeAsBytesSync(tinyJpeg(width: 80, height: 45));
    final exact = File(p.join(tmp.path, 'x.jpg'))
      ..writeAsBytesSync(tinyJpeg(width: 160, height: 90, shade: 250));
    final cache = FrameImageCache();
    await tester.runAsync(() async {
      (await cache.load(sheet.path))?.dispose();
      (await cache.load(exact.path))?.dispose();
    });
    final frame = ValueNotifier(
      FrameRef(sheet.path, cell: 6, cols: 5, rows: 5),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [frameImageCacheProvider.overrideWithValue(cache)],
        child: Center(
          child: ValueListenableBuilder(
            valueListenable: frame,
            builder: (_, f, _) => FrameView(frame: f, width: 160),
          ),
        ),
      ),
    );
    // Decoded already: painted in the first frame, no placeholder.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    frame.value = FrameRef(exact.path);
    await tester.pump();
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    // Cell to cell (scrubbing): no fade.
    frame.value = FrameRef(sheet.path, cell: 7, cols: 5, rows: 5);
    await tester.pump();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    cache.clear();
  });

  test('prefetch decodes the sheet under the finger and its neighbours', () {
    final specs = StoryboardLevel.forVideo(const Duration(minutes: 10));
    final board = Storyboard(
      source: '/v/f.mkv',
      duration: const Duration(minutes: 10),
      directory: tmp.path,
      levels: [
        LevelFrames(specs[0], sheets: const {0}),
        LevelFrames(specs[1], sheets: const {0, 1, 2, 3, 4}),
      ],
    );
    final cache = FrameImageCache();
    // 2:00 is frame 60 of the fine level: sheet 2.
    prefetchSheets(cache, board, const Duration(minutes: 2));
    expect(
      [
        board.sheetPath(0, 0),
        board.sheetPath(1, 1),
        board.sheetPath(1, 2),
        board.sheetPath(1, 3),
      ].every(cache.has),
      isTrue,
    );
    expect(cache.has(board.sheetPath(1, 4)), isFalse);
  });
}
