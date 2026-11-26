import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/utils/media_cache_key.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_player_backend.dart';

/// Task 8.1: one hidden mpv for all frame work.
void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kyndrel_engine');
    forgetMediaCacheKeys();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A fake mpv that writes one picture per loadfile/seek, like `vo=image`.
  FakePlayerBackend imageMpv({Duration delay = Duration.zero}) {
    final b = FakePlayerBackend();
    var n = 0;
    b.onCommand = (args) {
      if (args.first != 'loadfile' && args.first != 'seek') return;
      final out = b.properties['vo-image-outdir']!;
      final name = '${'${++n}'.padLeft(8, '0')}.jpg';
      void write() =>
          File(p.join(out, name)).writeAsBytesSync(const [0xFF, 0xD8]);
      if (delay == Duration.zero) {
        write();
      } else {
        Timer(delay, write);
      }
    };
    return b;
  }

  test('jobs run one at a time, the most urgent first', () async {
    final engine = FrameEngine(backendFactory: FakePlayerBackend.new);
    final order = <String>[];
    final hold = Completer<void>();
    final started = Completer<void>();
    final first = engine.run(FrameJob.storyboard, (_) async {
      order.add('storyboard');
      started.complete();
      await hold.future;
    });
    await started.future;
    final probe = engine.run(FrameJob.probe, (_) async => order.add('probe'));
    final exact = engine.run(FrameJob.exact, (_) async => order.add('exact'));
    hold.complete();
    await Future.wait([first, probe, exact]);
    expect(order, ['storyboard', 'exact', 'probe']);
    expect(engine.started, 1);
    await engine.dispose();
  });

  test('a long job is told to yield when something urgent waits', () async {
    final engine = FrameEngine(backendFactory: FakePlayerBackend.new);
    final seen = <bool>[];
    final waiting = Completer<void>();
    final started = Completer<void>();
    final long = engine.run(FrameJob.storyboard, (s) async {
      seen.add(s.shouldYield);
      started.complete();
      await waiting.future;
      seen.add(s.shouldYield);
    });
    await started.future;
    // Less urgent work doesn't interrupt it.
    final probe = engine.run(FrameJob.probe, (_) async {});
    await Future<void>.delayed(Duration.zero);
    final exact = engine.run(FrameJob.exact, (_) async {});
    waiting.complete();
    await Future.wait([long, probe, exact]);
    expect(seen, [false, true]);
    await engine.dispose();
  });

  test('mpv closes when idle and starts again on the next job', () async {
    final backends = <FakePlayerBackend>[];
    final engine = FrameEngine(
      backendFactory: () {
        final b = FakePlayerBackend();
        backends.add(b);
        return b;
      },
      idleTimeout: const Duration(milliseconds: 50),
    );
    expect(engine.isRunning, isFalse, reason: 'lazy');
    await engine.run(FrameJob.probe, (s) async {
      final b = s.backend as FakePlayerBackend;
      expect(b.properties['vd-lavc-skiploopfilter'], 'all');
      expect(b.properties['demuxer-max-bytes'], '4MiB');
    });
    expect(engine.isRunning, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(engine.isRunning, isFalse);
    expect(backends.single.disposed, isTrue);

    await engine.run(FrameJob.probe, (_) async {});
    expect(backends, hasLength(2));
    // Never two at once.
    expect(backends.where((b) => !b.disposed), hasLength(1));
    await engine.dispose();
    expect(backends.every((b) => b.disposed), isTrue);
  });

  test('releaseIdle closes mpv now; jobs after dispose fail', () async {
    final engine = FrameEngine(backendFactory: FakePlayerBackend.new);
    await engine.run(FrameJob.probe, (_) async {});
    await engine.releaseIdle();
    expect(engine.isRunning, isFalse);
    await engine.dispose();
    expect(
      () => engine.run(FrameJob.probe, (_) async {}),
      throwsA(isA<FrameEngineClosed>()),
    );
  });

  test(
    'a storyboard hands over for a seek-bar frame, then carries on',
    () async {
      // Pictures take a little while, so the preview arrives mid-render.
      final mpv = imageMpv(delay: const Duration(milliseconds: 20));
      final engine = FrameEngine(backendFactory: () => mpv);
      final storyboards = MpvStoryboardSource(engine: engine);
      final previews = PreviewThumbnailer(cacheDir: tmp, engine: engine);
      final board = Storyboard.read(
        tmp,
        '/v/film.mkv',
        const Duration(seconds: 40),
      );
      final events = <String>[];
      final render = storyboards.render(board).then((ok) {
        events.add('storyboard done');
        return ok;
      });
      while (mpv.commands.where((c) => c.first == 'seek').length < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final frame = await previews.frameAt(
        '/v/film.mkv',
        const Duration(seconds: 7),
        const Duration(seconds: 40),
        exact: true,
      );
      events.add('preview');
      expect(frame, isNotNull);
      expect(await render, isTrue);
      expect(events, ['preview', 'storyboard done']);

      final done = Storyboard.read(tmp, '/v/film.mkv', board.duration);
      expect(done.complete, isTrue);
      expect(done.available, hasLength(done.count));
      expect(engine.started, 1);
      await engine.dispose();
    },
  );

  test(
    'a second preview of the open file seeks instead of reloading',
    () async {
      final mpv = imageMpv();
      final engine = FrameEngine(backendFactory: () => mpv);
      final previews = PreviewThumbnailer(cacheDir: tmp, engine: engine);
      const length = Duration(minutes: 5);
      for (final s in [10, 20, 30]) {
        expect(
          await previews.frameAt(
            '/v/a.mkv',
            Duration(seconds: s),
            length,
            exact: true,
          ),
          isNotNull,
        );
        mpv.properties['time-pos'] = '$s';
      }
      final names = mpv.commands.map((c) => c.first).toList();
      expect(names.where((n) => n == 'loadfile'), hasLength(1));
      expect(names.where((n) => n == 'seek'), hasLength(2));
      await engine.dispose();
    },
  );

  test('library pictures wait for frames the user is looking at', () async {
    final mpv = imageMpv(delay: const Duration(milliseconds: 20));
    final engine = FrameEngine(backendFactory: () => mpv);
    final previews = PreviewThumbnailer(cacheDir: tmp, engine: engine);
    const length = Duration(minutes: 5);
    final order = <String>[];
    final hold = Completer<void>();
    // Something holds the engine while both requests arrive.
    final busy = engine.run(FrameJob.storyboard, (_) => hold.future);
    final library = previews
        .frameAt('/v/lib.mkv', length * 0.1, length, background: true)
        .then((_) => order.add('library'));
    final hover = previews
        .frameAt('/v/now.mkv', const Duration(seconds: 3), length, exact: true)
        .then((_) => order.add('hover'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    hold.complete();
    await Future.wait([busy, library, hover]);
    expect(order, ['hover', 'library']);
    await engine.dispose();
  });
}
