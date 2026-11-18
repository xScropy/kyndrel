@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// The PLAN.md 5.5 test matrix against the real libmpv: HDR10 4K HEVC
/// Main 10, AV1, 10-bit H.264, variable frame rate, a truncated MKV, a huge
/// subtitle file and a connection dropped mid-stream. (Multi-audio and
/// image subtitles are covered in `engine_test.dart`.) Media comes from
/// `scripts/make_test_media.sh` (`test_media/generated/matrix/`).
void main() {
  final media = p.absolute('test_media/generated');
  String matrix(String name) => p.join(media, 'matrix', name);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    if (!File(matrix('vfr.mkv')).existsSync()) {
      fail('Run scripts/make_test_media.sh first.');
    }
  });

  late PlayerService service;

  setUp(() async {
    service = PlayerService(MediaKitBackend(withVideo: false));
    await service.backend.setProperty('ao', 'null');
    await service.backend.setProperty('vo', 'null');
    await service.backend.setProperty('vid', 'auto');
  });

  tearDown(() => service.dispose());

  Future<PlaybackState> waitFor(
    bool Function(PlaybackState) test, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    if (test(service.state)) return Future.value(service.state);
    return service.states.firstWhere(test).timeout(timeout);
  }

  Future<String?> prop(String name) => service.backend.getProperty(name);

  Future<void> eventually(
    Future<bool> Function() check, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await check()) {
      if (DateTime.now().isAfter(end)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> playsAndSeeks(String path, Duration to) async {
    if (!File(path).existsSync()) {
      markTestSkipped('${p.basename(path)} not generated (encoder missing)');
      return;
    }
    await service.open(path);
    await waitFor((s) => s.duration > Duration.zero && s.isPlaying);
    // Frames are actually decoded, not just the container read.
    await eventually(
      () async =>
          (int.tryParse(await prop('estimated-frame-number') ?? '') ?? 0) > 0,
    );
    await service.seek(to);
    await waitFor((s) => s.position >= to);
    expect(service.state.status, isNot(PlaybackStatus.error));
  }

  test('HDR10 4K HEVC Main 10: decodes and reports PQ / BT.2020', () async {
    await playsAndSeeks(matrix('hdr10_4k_hevc10.mp4'), Duration.zero);
    expect(await prop('video-codec'), contains('HEVC'));
    expect(await prop('video-params/w'), '3840');
    expect(await prop('video-params/pixelformat'), contains('10'));
    expect(await prop('video-params/gamma'), 'pq');
    expect(await prop('video-params/primaries'), 'bt.2020');
  });

  test('AV1', () async {
    await playsAndSeeks(matrix('av1.mkv'), const Duration(seconds: 1));
    expect(await prop('video-codec'), contains('AV1'));
  });

  test('10-bit H.264', () async {
    await playsAndSeeks(matrix('h264_10bit.mp4'), const Duration(seconds: 2));
    expect(await prop('video-params/pixelformat'), contains('10'));
  });

  test('variable frame rate plays, seeks into each half and ends', () async {
    await playsAndSeeks(matrix('vfr.mkv'), const Duration(seconds: 2));
    expect(service.state.duration.inSeconds, inInclusiveRange(7, 8));
    await service.seek(const Duration(seconds: 6));
    await waitFor((s) => s.position >= const Duration(seconds: 6));
    await waitFor((s) => s.isCompleted);
  });

  test(
    'a truncated MKV plays what is there, then says it ends early',
    () async {
      await service.open(matrix('truncated.mkv'));
      await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
      // Jump close to the cut; mpv hits the end of the data and stops.
      await service.seek(const Duration(seconds: 10));
      final end = await waitFor(
        (s) => s.isCompleted || s.status == PlaybackStatus.error,
        timeout: const Duration(seconds: 40),
      );
      // Not "completed": a cut-off film must not count as watched.
      expect(end.status, PlaybackStatus.error);
      expect(end.errorMessage, contains('ends early'));

      // The player is still usable afterwards.
      await service.open(p.join(media, 'clip.mp4'));
      await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
    },
  );

  test('a 100 000-cue subtitle file loads in seconds', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    final before = service.tracks.subtitles.length;
    final watch = Stopwatch()..start();
    await service.addSubtitle(matrix('huge.srt'));
    await eventually(() async => service.tracks.subtitles.length > before);
    watch.stop();
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    // Still responsive: seeking works with the big track selected.
    await service.seek(const Duration(seconds: 5));
    await waitFor((s) => s.position >= const Duration(seconds: 5));
  });

  group('network drop mid-stream', () {
    // A bare HTTP server that sends the first 40 % of the file and then
    // resets the connection. Range requests (mpv's reconnect) get the rest
    // only when [allowResume] is set.
    late ServerSocket server;
    var allowResume = false;
    var requests = 0;

    setUp(() async {
      allowResume = false;
      requests = 0;
      final bytes = File(matrix('faststart.mp4')).readAsBytesSync();
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0)
        ..listen((socket) async {
          requests++;
          final head = StringBuffer();
          await for (final chunk in socket) {
            head.write(String.fromCharCodes(chunk));
            if (head.toString().contains('\r\n\r\n')) break;
          }
          final range = RegExp(r'Range: bytes=(\d+)-').firstMatch('$head');
          final from = int.parse(range?.group(1) ?? '0');
          if (from > 0 && !allowResume) {
            socket.destroy();
            return;
          }
          final status = from > 0 ? '206 Partial Content' : '200 OK';
          final total = bytes.length;
          final range206 = from > 0
              ? 'Content-Range: bytes $from-${total - 1}/$total\r\n'
              : '';
          final cut = from > 0 ? total : (total * 0.4).round();
          socket
            ..write(
              'HTTP/1.1 $status\r\n'
              'Content-Type: video/mp4\r\n'
              'Accept-Ranges: bytes\r\n'
              'Content-Length: ${total - from}\r\n'
              '$range206'
              '\r\n',
            )
            ..add(bytes.sublist(from, cut));
          await socket.flush();
          socket.destroy();
        });
    });
    tearDown(() => server.close());

    String url() => 'http://127.0.0.1:${server.port}/clip.mp4';

    test('the server goes away: playback stops, no hang', () async {
      await service.open(url());
      await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
      final watch = Stopwatch()..start();
      final end = await waitFor(
        (s) => s.isCompleted || s.status == PlaybackStatus.error,
        timeout: const Duration(seconds: 60),
      );
      // ignore: avoid_print, the numbers go into docs/test-matrix.md
      print('drop: ${end.status} at ${end.position} after ${watch.elapsed}');
      expect(end.status, PlaybackStatus.error);
      expect(end.errorMessage, contains('connection was lost'));
      // It got through the part that arrived before the drop, and gave up
      // within the capped reconnect backoff (0+1+3+7+15 s plus playback).
      expect(end.position, greaterThan(const Duration(seconds: 1)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 45)));

      await service.open(p.join(media, 'clip.mp4'));
      await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
    });

    test('the server comes back: playback resumes and finishes', () async {
      allowResume = true;
      await service.open(url());
      await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
      final end = await waitFor(
        (s) => s.isCompleted || s.status == PlaybackStatus.error,
        timeout: const Duration(seconds: 60),
      );
      expect(end.status, PlaybackStatus.completed);
      expect(end.position, greaterThan(const Duration(seconds: 28)));
      expect(requests, greaterThan(1), reason: 'mpv did not reconnect');
    });
  });
}
