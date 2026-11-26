@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Task 7.2 with the real libmpv: one pass writes the whole storyboard.
///   scripts/make_test_media.sh && flutter test -t engine --run-skipped
void main() {
  final media = p.absolute('test_media/generated');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  });

  late Directory cache;
  late MpvStoryboardSource source;
  setUp(() {
    cache = Directory.systemTemp.createTempSync('kyndrel_sb_engine');
    source = MpvStoryboardSource();
  });
  tearDown(() async {
    await source.dispose().timeout(const Duration(seconds: 20));
    cache.deleteSync(recursive: true);
  });

  for (final (file, length) in [
    ('clip.mp4', const Duration(seconds: 8)),
    ('The.Test.Film.2019.1080p.mkv', const Duration(seconds: 30)),
  ]) {
    test('$file: every level, packed into sheets', () async {
      final path = p.join(media, file);
      final board = Storyboard.read(cache, path, length);
      final watch = Stopwatch()..start();
      expect(await source.render(board), isTrue);
      final done = Storyboard.read(cache, path, length);
      expect(done.complete, isTrue);
      for (final l in done.levels) {
        expect(l.tiles, isEmpty, reason: 'all packed');
        expect(l.sheets, hasLength(l.spec.sheetCount));
        // Every frame but possibly the very last (the file may end first).
        expect(l.failed.length, lessThanOrEqualTo(1));
        final sheet = File(done.sheetPath(l.spec.index, 0)).readAsBytesSync();
        expect(sheet.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG');
      }
      final frames = done.levels.fold(0, (n, l) => n + l.ready);
      // ignore: avoid_print, the timing goes in the CI log
      print('$file: $frames frames in ${watch.elapsed}');
    });
  }

  test('cancel stops a render', () async {
    final path = p.join(media, 'The.Test.Film.2019.1080p.mkv');
    final board = Storyboard.read(cache, path, const Duration(seconds: 30));
    final run = source.render(board);
    await source.cancel();
    expect(await run, isFalse);
    expect(Storyboard.read(cache, path, board.duration).complete, isFalse);
  });
}
