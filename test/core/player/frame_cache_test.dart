import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/android_frame_source.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/scrub_preview.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_player_backend.dart';
import '../../support/fake_preview_source.dart';
import '../../support/tiny_jpeg.dart';

/// Task 8.0: cache keys, the storyboard cancel race, honest completeness,
/// and the preview queue.
void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kyndrel_frames');
    forgetMediaCacheKeys();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('cache key', () {
    test('a file replaced at the same path gets a new key', () {
      final file = File(p.join(tmp.path, 'a.mkv'))..writeAsBytesSync([1]);
      final before = mediaCacheKey(file.path);
      expect(mediaCacheKey(file.path), before, reason: 'remembered');
      file.writeAsBytesSync([1, 2, 3]);
      forgetMediaCacheKeys();
      expect(mediaCacheKey(file.path), isNot(before));
    });

    test('streams, content URIs and missing files: the source alone', () {
      for (final s in [
        'https://x.example/a.m3u8',
        'content://media/external/video/media/7',
        '/no/such/file.mkv',
      ]) {
        expect(mediaCacheKey(s), fnv1a64(s));
      }
    });

    test('local paths of file URIs', () {
      expect(localPathOf('file:///v/a%20b.mkv'), '/v/a b.mkv');
      expect(localPathOf('/v/a.mkv'), '/v/a.mkv');
      expect(localPathOf('file://server/share/a.mkv'), isNull);
      expect(localPathOf('smb://server/a.mkv'), isNull);
    });
  });

  group('desktop storyboard render', () {
    /// A fake mpv that writes one picture per loadfile/seek, like `vo=image`.
    final jpeg = tinyJpeg();
    FakePlayerBackend imageMpv() {
      final b = FakePlayerBackend();
      var n = 0;
      b.onCommand = (args) {
        if (args.first == 'loadfile' || args.first == 'seek') {
          final out = b.properties['vo-image-outdir']!;
          n++;
          File(p.join(out, '${'$n'.padLeft(8, '0')}.jpg'))
              .writeAsBytesSync(jpeg);
        }
      };
      return b;
    }

    Storyboard board() =>
        Storyboard.read(tmp, '/v/film.mkv', const Duration(seconds: 10));

    test('a newer render stops the older one; they never overlap', () async {
      final mpv = imageMpv();
      final source = MpvStoryboardSource(backendFactory: () => mpv);
      final first = source.render(board());
      // Wait until the first render is working on the file.
      while (!mpv.commands.any((c) => c.first == 'loadfile')) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await source.cancel();
      final second = source.render(board());
      expect(await first, isFalse);
      expect(await second, isTrue);

      // The first render stopped (unloading the file) before the second
      // loaded it again.
      final names = mpv.commands.map((c) => c.first).toList();
      final stop = names.indexOf('stop');
      expect(stop, greaterThan(names.indexOf('loadfile')));
      expect(names.lastIndexOf('loadfile'), greaterThan(stop));
      final done = board();
      expect(done.complete, isTrue);
      // Packed into sheets: no loose tiles left.
      expect(done.levels.every((l) => l.tiles.isEmpty), isTrue);
      expect(File(done.sheetPath(1, 0)).existsSync(), isTrue);
      await source.dispose();
    });

    test('a render replaced before it starts does nothing', () async {
      final mpv = imageMpv();
      final source = MpvStoryboardSource(backendFactory: () => mpv);
      final first = source.render(board());
      final second = source.render(board());
      expect(await first, isFalse);
      expect(await second, isTrue);
      // One load per level.
      expect(mpv.commands.where((c) => c.first == 'loadfile'), hasLength(2));
      await source.dispose();
    });
  });

  group('Android storyboard', () {
    const channel = MethodChannel('kyndrel/frames.sb-test');
    late Set<int> skip;
    final jpeg = tinyJpeg();

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      skip = {};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = (call.arguments as Map).cast<String, Object?>();
            final dir = Directory(args['dir']! as String)
              ..createSync(recursive: true);
            final fine = args['width'] == 160;
            for (var i = 0; i < (args['count']! as int); i++) {
              if (fine && skip.contains(i)) continue;
              File(p.join(dir.path, '$i.jpg')).writeAsBytesSync(jpeg);
            }
            // Android reports success after the loop, even with gaps.
            return true;
          });
    });

    // 300 s: 100 coarse frames, then one every 2 s → 150 fine frames, of
    // which up to 15 may fail.
    Storyboard board() =>
        Storyboard.read(tmp, '/v/b.mkv', const Duration(seconds: 300));

    test('a few undecodable frames are recorded as failed', () async {
      skip = {7, 8};
      final source = AndroidStoryboardSource(channel: channel);
      expect(await source.render(board()), isTrue);
      final done = board();
      expect(done.complete, isTrue);
      expect(done.levels[1].failed, {7, 8});
      // Packed at the end of each level: 1 coarse sheet, 6 fine ones.
      expect(done.levels.map((l) => l.sheets.length), [1, 6]);
      expect(done.levels.every((l) => l.tiles.isEmpty), isTrue);
      final spec = jsonDecode(
        File(p.join(done.directory, 'spec.json')).readAsStringSync(),
      ) as Map;
      final levels = spec['levels'] as Map;
      expect((levels['1'] as Map)['failed'], [7, 8]);
    });

    test('many gaps: left unfinished, to try again later', () async {
      skip = {for (var i = 0; i < 40; i++) i + 1};
      final source = AndroidStoryboardSource(channel: channel);
      expect(await source.render(board()), isFalse);
      expect(board().complete, isFalse);
      expect(board().levels[0].complete, isTrue);
      expect(board().levels[1].complete, isFalse);
    });
  });

  test(
    'preview queue: old hover positions are dropped, newest first',
    () async {
      final mpv = FakePlayerBackend();
      final rendered = <String>[];
      mpv.onCommand = (args) {
        if (args.first != 'loadfile') return;
        rendered.add(mpv.properties['start']!);
        File(p.join(mpv.properties['vo-image-outdir']!, '00000001.jpg'))
            .writeAsBytesSync(const [0xFF, 0xD8]);
      };
      final t = PreviewThumbnailer(cacheDir: tmp, backendFactory: () => mpv);
      const length = Duration(minutes: 5);
      final results = [
        for (final s in [10, 20, 30, 40, 50])
          t.frameAt('/v/c.mkv', Duration(seconds: s), length, exact: true),
      ];
      final paths = await Future.wait(results);
      // 10 s starts at once; 20 s is dropped when 50 s arrives (3 waiting at
      // most); the rest render newest first.
      expect(rendered, ['10', '50', '40', '30']);
      expect(paths[1], isNull);
      expect([paths[0], paths[2], paths[3], paths[4]], everyElement(isNotNull));
      // Cached now: no new render.
      await t.frameAt(
        '/v/c.mkv',
        const Duration(seconds: 50),
        length,
        exact: true,
      );
      expect(rendered, hasLength(4));
      await t.dispose();
    },
  );

  group('ScrubPreview timing', () {
    late FakePreviewSource previews;
    late List<FrameRef> shown;
    late List<Duration> focused;
    late ScrubPreview scrub;

    Future<void> setUpScrub(WidgetTester tester, Storyboard? board) async {
      previews = FakePreviewSource('/tmp/exact.jpg');
      shown = [];
      focused = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            previewSourceProvider.overrideWithValue(previews),
            storyboardProvider.overrideWith(
              () => _FixedBoard(board, focused.add),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              scrub = ScrubPreview(ref, shown.add);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    const length = Duration(minutes: 1);
    // The fine level (a frame every 2 s) has its first six frames so far.
    final specs = StoryboardLevel.forVideo(length);
    final board = Storyboard(
      source: '/v/d.mkv',
      duration: length,
      directory: '/c',
      levels: [
        LevelFrames(specs[0]),
        LevelFrames(specs[1], tiles: const {0, 1, 2, 3, 4, 5}),
      ],
    );
    const tile2 = FrameRef('/c/L1/tiles/2.jpg');

    testWidgets('storyboard frame at once, exact frame after resting', (
      tester,
    ) async {
      await setUpScrub(tester, board);
      scrub.request('/v/d.mkv', const Duration(seconds: 4), length);
      expect(shown, [tile2]);
      await tester.pump(ScrubPreview.rest - const Duration(milliseconds: 1));
      expect(previews.exactRequests, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(previews.exactRequests, [const Duration(seconds: 4)]);
      expect(shown.last, const FrameRef('/tmp/exact.jpg'));
      // The storyboard isn't finished: frames near the finger come next.
      expect(focused, [const Duration(seconds: 4)]);
    });

    testWidgets('moving keeps postponing the exact frame', (tester) async {
      await setUpScrub(tester, board);
      for (final s in [2, 4, 6, 8]) {
        scrub.request('/v/d.mkv', Duration(seconds: s), length);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(ScrubPreview.rest);
      await tester.pump();
      expect(previews.exactRequests, [const Duration(seconds: 8)]);
    });

    testWidgets('no storyboard: nearest step after a short wait', (
      tester,
    ) async {
      await setUpScrub(tester, null);
      scrub.request('/v/d.mkv', const Duration(seconds: 4), length);
      expect(shown, isEmpty);
      await tester.pump(ScrubPreview.debounce);
      await tester.pump();
      expect(previews.requests, [const Duration(seconds: 4)]);
      expect(previews.exactRequests, isEmpty);
    });

    testWidgets('cancel drops a pending frame', (tester) async {
      await setUpScrub(tester, board);
      scrub
        ..request('/v/d.mkv', const Duration(seconds: 4), length)
        ..cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(previews.exactRequests, isEmpty);
      expect(shown, [tile2]);
    });
  });
}

class _FixedBoard extends StoryboardController {
  new(this.board, this.onFocus);
  final Storyboard? board;
  final void Function(Duration at) onFocus;

  @override
  Storyboard? build() => board;

  @override
  void focus(Duration at) => onFocus(at);
}
