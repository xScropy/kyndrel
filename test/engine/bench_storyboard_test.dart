@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:media_kit/media_kit.dart';

/// The storyboard benchmark (task 8.2), run by `scripts/bench_storyboard.sh`;
/// skipped without its clip.
void main() {
  final media = Platform.environment['KYNDREL_BENCH_MEDIA'];
  final seconds = int.tryParse(
    Platform.environment['KYNDREL_BENCH_SECONDS'] ?? '',
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  });

  test(
    'a full storyboard of a long clip',
    () async {
      // `--run-skipped` runs it anyway: without the clip there is nothing
      // to measure.
      if (media == null || seconds == null) {
        markTestSkipped('run scripts/bench_storyboard.sh');
        return;
      }
      final cache = Directory.systemTemp.createTempSync('kyndrel_bench');
      final engine = FrameEngine();
      final source = MpvStoryboardSource(engine: engine);
      final length = Duration(seconds: seconds);
      final board = Storyboard.read(cache, media, length);
      final rssBefore = ProcessInfo.currentRss;
      final watch = Stopwatch()..start();
      Duration? coarse;
      final ok = await source.render(
        board,
        onChange: (b) => coarse ??= b.levels[0].complete ? watch.elapsed : null,
      );
      final total = watch.elapsed;
      final done = Storyboard.read(cache, media, length);
      final frames = done.levels.fold(0, (n, l) => n + l.ready);
      var bytes = 0;
      for (final f in Directory(done.directory).listSync(recursive: true)) {
        if (f is File) bytes += f.lengthSync();
      }
      // ignore: avoid_print, the benchmark's output
      print(
        'bench ok=$ok length=${length.inMinutes}min frames=$frames '
        'coarse-level=${coarse?.inMilliseconds}ms '
        'total=${total.inMilliseconds}ms '
        'per-frame=${(total.inMilliseconds / frames).toStringAsFixed(1)}ms '
        'disk=${(bytes / 1024).round()}KB '
        'rss-before=${rssBefore >> 20}MB '
        'peak-rss=${ProcessInfo.maxRss >> 20}MB',
      );
      await engine.dispose();
      cache.deleteSync(recursive: true);
      expect(ok, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
