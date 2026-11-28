import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/player/storyboard_writer.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:path/path.dart' as p;

import '../../support/tiny_jpeg.dart';

/// Task 8.2: the order frames are made in, and packing them into sheets.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kyndrel_writer'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Storyboard board(Duration length) => Storyboard.read(tmp, '/v/w.mkv', length);

  test('coarse to fine, but frames near the finger first', () {
    final w = StoryboardWriter(board(const Duration(minutes: 10)));
    // The fine level: 300 frames.
    expect(w.next(1), 0);
    w.tileWritten(1, 0);
    expect(w.next(1), 256);
    w.focus = const Duration(seconds: 100); // Frame 50.
    expect(w.next(1), 50);
    w.tileWritten(1, 50);
    expect(w.next(1), 51);
    w.tileFailed(1, 51);
    expect(w.next(1), 49);
    w.focus = null;
    expect(w.next(1), 256);
  });

  test('a full sheet is packed at once and its tiles deleted', () async {
    final changes = <Storyboard>[];
    final b = board(const Duration(minutes: 1)); // Fine: 30 frames, 2 sheets.
    final w = StoryboardWriter(b, onChange: changes.add);
    final jpeg = tinyJpeg(width: 32, height: 18);
    Directory(b.tilesDirectory(1)).createSync(recursive: true);
    for (var i = 0; i < 25; i++) {
      File(b.tilePath(1, i)).writeAsBytesSync(jpeg);
      if (i == 3) {
        w.tileFailed(1, i);
      } else {
        w.tileWritten(1, i);
      }
    }
    await w.flush();
    final l = w.board.levels[1];
    expect(l.sheets, {0});
    expect(l.tiles, isEmpty);
    expect(l.has(3), isFalse, reason: 'failed: its cell is empty');
    expect(w.board.frame(1, 7)?.cell, 7);
    expect(File(b.tilePath(1, 7)).existsSync(), isFalse);
    // The sheet is a 5×5 grid of the tiles.
    final codec = await ui.instantiateImageCodec(
      File(b.sheetPath(1, 0)).readAsBytesSync(),
    );
    final image = (await codec.getNextFrame()).image;
    expect((image.width, image.height), (160, 90));
    expect(changes.last.levels[1].sheets, {0});

    // Finishing: the rest are failed, the half-full sheet is packed, and
    // too many failures keep the level unfinished.
    await w.finishLevel(1);
    expect(w.board.levels[1].sheets, {0, 1});
    expect(w.board.levels[1].complete, isFalse);
    expect(Storyboard.read(tmp, '/v/w.mkv', b.duration).levels[1].sheets, {
      0,
      1,
    });
  });

  test('packing fails on unreadable tiles: they stay', () async {
    final b = board(const Duration(minutes: 1));
    expect(
      packSheetSync(
        [p.join(tmp.path, 'missing.jpg')],
        5,
        5,
        p.join(tmp.path, 'out.jpg'),
        75,
      ),
      isFalse,
    );
    final w = StoryboardWriter(b);
    Directory(b.tilesDirectory(0)).createSync(recursive: true);
    for (var i = 0; i < b.levels[0].spec.count; i++) {
      File(b.tilePath(0, i)).writeAsBytesSync(const [1, 2, 3]);
      w.tileWritten(0, i);
    }
    await w.flush();
    expect(w.board.levels[0].sheets, isEmpty);
    expect(w.board.levels[0].tiles, hasLength(60));
  });

  testWidgets('decoded sheets: least recently used go first', (tester) async {
    await tester.runAsync(() async {
      final paths = [
        for (var i = 0; i < 3; i++)
          (File(
            p.join(tmp.path, '$i.jpg'),
          )..writeAsBytesSync(tinyJpeg(width: 64, height: 64))).path,
      ];
      // Room for two 64×64 images.
      final cache = FrameImageCache(maxBytes: 2 * 64 * 64 * 4);
      final a = (await cache.load(paths[0]))!;
      final b = (await cache.load(paths[1]))!;
      expect(cache.length, 2);
      cache.peek(paths[0])?.dispose(); // 0 is used again: 1 is oldest.
      final c = (await cache.load(paths[2]))!;
      expect(cache.length, 2);
      expect(cache.peek(paths[1]), isNull);
      expect(cache.peek(paths[0]), isNotNull);
      // Handles stay valid after eviction: they are clones.
      expect(b.width, 64);
      for (final i in [a, b, c]) {
        i.dispose();
      }
      cache.clear();
      expect(cache.bytes, 0);
    });
  });
}
