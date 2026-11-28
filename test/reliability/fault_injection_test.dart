import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/net/ftp_client.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/android_frame_source.dart';
import 'package:kyndrel/core/player/intro_detector.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/player/storyboard_writer.dart';
import 'package:kyndrel/core/subtitles/subtitle_file.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:path/path.dart' as p;

import '../support/tiny_jpeg.dart';

/// Task 8.11: things going wrong, and inputs nobody planned for.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kyndrel_faults'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('fault injection', () {
    test(
      "a sheet that can't be written: tiles stay, the next sheet packs",
      () async {
        final board = Storyboard.read(
          tmp,
          '/v/f.mkv',
          const Duration(minutes: 1),
        );
        final w = StoryboardWriter(board);
        // A folder where sheet 0 should go: writing it fails, like a full disk.
        Directory(board.sheetPath(1, 0)).createSync(recursive: true);
        Directory(board.tilesDirectory(1)).createSync(recursive: true);
        final jpeg = tinyJpeg();
        for (var i = 0; i < 30; i++) {
          File(board.tilePath(1, i)).writeAsBytesSync(jpeg);
          w.tileWritten(1, i);
        }
        await w.finishLevel(1);
        final l = w.board.levels[1];
        expect(l.sheets, {1}, reason: 'sheet 1 packed after sheet 0 failed');
        expect(l.tiles, hasLength(25), reason: "sheet 0's tiles kept");
        expect(l.complete, isFalse);
        expect(w.board.nearest(const Duration(seconds: 4)), isNotNull);
      },
    );

    test('a corrupt spec or sheet never throws', () async {
      final dir = Storyboard.directoryFor(tmp, '/v/g.mkv');
      Directory(dir).createSync(recursive: true);
      File(p.join(dir, 'spec.json'))
          .writeAsStringSync('{"version": 2, "levels": [');
      final board = Storyboard.read(
        tmp,
        '/v/g.mkv',
        const Duration(minutes: 1),
      );
      expect(board.complete, isFalse);
      expect(Storyboard.readSaved(tmp, '/v/g.mkv'), isNull);

      // A spec that claims a sheet whose file is garbage.
      final b = Storyboard.read(tmp, '/v/h.mkv', const Duration(minutes: 1));
      Directory(b.levelDirectory(0)).createSync(recursive: true);
      File(b.sheetPath(0, 0)).writeAsBytesSync([1, 2, 3, 4]);
      final claimed = b.withLevel(
        b.levels[0].copyWith(sheets: {0}, complete: true),
      );
      final hashes = await storyboardHashes(claimed, 0);
      expect(hashes.every((h) => h == null), isTrue);
    });

    test(
      'the desktop scan survives broken links and missing folders',
      () async {
        final films = Directory(p.join(tmp.path, 'Films'))..createSync();
        File(p.join(films.path, 'a.mkv')).writeAsStringSync('x');
        Link(p.join(films.path, 'gone.mkv'))
            .createSync(p.join(tmp.path, 'nope'));
        final found = FolderMediaScanner.scanSync([
          films.path,
          p.join(tmp.path, 'not-there'),
        ]);
        expect(found.map((f) => f.name), ['a.mkv']);
      },
    );

    test('a stuck Android frame request gives up; the queue goes on', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('kyndrel/frames.stuck');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            calls++;
            final args = (call.arguments as Map).cast<String, Object?>();
            if (calls == 1) return Completer<Object?>().future; // Never.
            File(args['path']! as String)
              ..createSync(recursive: true)
              ..writeAsBytesSync([1]);
            return Future.value(true);
          });
      final s = AndroidFrameSource(
        cacheDir: tmp,
        channel: channel,
        frameTimeout: const Duration(milliseconds: 100),
      );
      const length = Duration(minutes: 5);
      final stuck = s.frameAt('/v/x.mkv', const Duration(seconds: 10), length);
      expect(await stuck, isNull);
      final next = await s.frameAt(
        '/v/x.mkv',
        const Duration(seconds: 60),
        length,
      );
      expect(next, isNotNull);
    });
  });

  group('fuzzing', () {
    final rnd = math.Random(42);
    const alphabet =
        'abcXYZ019 .-_[](){}:;,/\\|%&\$#@!~`\'"\n\t\r'
        'éßøñ漢字العربية😀\u0000‏';
    String noise(int max) => String.fromCharCodes([
      for (var i = rnd.nextInt(max); i > 0; i--)
        alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
    ]);

    test('file names, times and command lines never throw', () {
      for (var i = 0; i < 3000; i++) {
        final s = noise(60);
        parseEpisode('/v/$s.mkv');
        parseMediaTitle(s);
        parseTimeInput(s, duration: const Duration(hours: 1));
        parseQuickCommands([s, '$s | $s']);
        parseMlsd(s);
        parseUnixList(s);
      }
    });

    test('subtitle files never throw', () {
      for (var i = 0; i < 500; i++) {
        String timing() =>
            '00:0${rnd.nextInt(9)}:01,000 --> 00:00:0${rnd.nextInt(9)},500';
        final body = [
          for (var j = 0; j < 5; j++)
            if (rnd.nextBool()) timing() else noise(40),
        ].join('\n');
        for (final ext in ['srt', 'vtt', 'ass', null]) {
          parseSubtitles(body, extension: ext);
        }
      }
    });

    test('storyboard specs never throw', () {
      final dir = Storyboard.directoryFor(tmp, '/v/fuzz.mkv');
      for (var i = 0; i < 300; i++) {
        Directory(dir).createSync(recursive: true);
        final spec = rnd.nextBool()
            ? noise(80)
            : jsonEncode({
                'version': rnd.nextInt(3),
                'durationMs': rnd.nextInt(1 << 30) - 1000,
                'levels': {
                  '${rnd.nextInt(3)}': {
                    'width': rnd.nextInt(400),
                    'sheets': [rnd.nextInt(50), 'x', null],
                    'failed': rnd.nextBool() ? [1, 2] : 'nope',
                    'complete': rnd.nextBool(),
                  },
                },
              });
        File(p.join(dir, 'spec.json')).writeAsStringSync(spec);
        Storyboard.read(
          tmp,
          '/v/fuzz.mkv',
          Duration(seconds: rnd.nextInt(9000)),
        );
        Storyboard.readSaved(tmp, '/v/fuzz.mkv');
      }
    });
  });
}
