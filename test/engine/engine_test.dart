@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/features/translate/translate_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// PlayerService against the real libmpv (PLAN.md Phase 1 and 2 exit
/// criteria). Run with:
///   scripts/make_test_media.sh && flutter test -t engine
void main() {
  final media = p.absolute('test_media/generated');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    if (!File(p.join(media, 'clip.mp4')).existsSync()) {
      fail('Run scripts/make_test_media.sh first.');
    }
  });

  late PlayerService service;

  setUp(() async {
    service = PlayerService(MediaKitBackend(withVideo: false));
    // No sound card in CI, and no video surface in a headless test: decode
    // video into the null output so video properties exist.
    await service.backend.setProperty('ao', 'null');
    await service.backend.setProperty('vo', 'null');
    await service.backend.setProperty('vid', 'auto');
  });

  // A stuck dispose fails this test instead of stalling the whole job.
  tearDown(() => service.dispose().timeout(const Duration(seconds: 20)));

  // Checks the current state too: the event may already have happened.
  Future<PlaybackState> waitFor(
    bool Function(PlaybackState) test, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (test(service.state)) return service.state;
    return await service.states.firstWhere(test).timeout(timeout);
  }

  Future<void> eventually(
    Future<bool> Function() check, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await check()) {
      if (DateTime.now().isAfter(end)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<String?> prop(String name) => service.backend.getProperty(name);

  group('formats play and seek', () {
    for (final file in [
      'clip.mp4',
      'clip.avi',
      'clip.webm',
      'hls.m3u8',
      'clip_hevc.mp4',
      'The.Test.Film.2019.1080p.mkv',
    ]) {
      test(file, () async {
        final path = p.join(media, file);
        if (!File(path).existsSync()) {
          markTestSkipped('$file not generated');
          return;
        }
        await service.open(path);
        final loaded = await waitFor(
          (s) => s.duration > Duration.zero && s.isPlaying,
        );
        expect(loaded.status, PlaybackStatus.playing);
        expect(await prop('video-codec'), isNotEmpty);

        await service.seek(const Duration(seconds: 3));
        await waitFor((s) => s.position >= const Duration(seconds: 3));
        expect(service.state.status, isNot(PlaybackStatus.error));
      });
    }
  });

  test('output devices; ao-reload keeps playing (no-sound retry)', () async {
    final devices = await service.audioDevices();
    expect(devices.first, SoundDevice.automatic);
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.duration > Duration.zero && s.isPlaying);
    await service.backend.command(['ao-reload']);
    await service.setAudioDevice('auto');
    expect(await prop('audio-device'), 'auto');
    final before = service.state.position;
    await waitFor((s) => s.position > before);
    expect(service.state.status, PlaybackStatus.playing);
  });

  test('a file that is not media reports an error with log lines', () async {
    await service.open(p.join(media, 'broken.mkv'));
    final s = await waitFor((s) => s.status == PlaybackStatus.error);
    expect(s.errorMessage, isNotEmpty);
    // Log lines arrive on their own stream; give them a moment.
    await eventually(() async => service.logExcerpt().isNotEmpty);
  });

  test('a missing file reports an error', () async {
    await service.open(p.join(media, 'does-not-exist.mkv'));
    final s = await waitFor((s) => s.status == PlaybackStatus.error);
    expect(s.errorMessage, isNotEmpty);
  });

  test('volume reaches 500 % and the limiter is added above 100 %', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await service.setVolume(500);
    await eventually(() async => double.parse((await prop('volume'))!) == 500);
    expect(await prop('volume-max'), startsWith('500'));
    expect(await prop('af'), contains('alimiter'));
    await service.setVolume(80);
    await eventually(
      () async => !(await prop('af') ?? '').contains('alimiter'),
    );
  });

  test('speed changes keep pitch correction on', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await service.setRate(1.5);
    await eventually(() async => await prop('speed') == '1.500000');
    expect(await prop('audio-pitch-correction'), 'yes');
  });

  group('tracks', () {
    Future<void> openFilm() async {
      await service.setAutoLoadSubtitles(enabled: true);
      await service.open(p.join(media, 'The.Test.Film.2019.1080p.mkv'));
      await waitFor((s) => s.isPlaying);
      await eventually(() async => service.tracks.subtitles.length >= 3);
    }

    test(
      'embedded, image and auto-loaded external tracks are listed',
      () async {
        await openFilm();
        final t = service.tracks;
        expect(t.audio.map((a) => a.language), ['eng', 'ara']);
        expect(t.audio.first.title, 'Stereo');
        final subs = t.subtitles;
        expect(
          subs.where((s) => s.codec == 'subrip' && !s.isExternal),
          hasLength(1),
        );
        expect(subs.where((s) => s.isImageSubtitle), hasLength(1));
        final external = subs.firstWhere((s) => s.isExternal);
        expect(external.externalFilename, endsWith('.ar.srt'));
        expect(external.language, 'ar');
      },
    );

    test('sid, secondary-sid, aid and delays', () async {
      await openFilm();
      final pgs = service.tracks.subtitles.firstWhere((s) => s.isImageSubtitle);
      await service.selectSubtitle(pgs.id);
      await eventually(() async => service.tracks.subtitleId == pgs.id);
      await service.selectSubtitle(null);
      await eventually(() async => service.tracks.subtitleId == null);
      expect(await prop('sid'), 'no');

      final srt = service.tracks.subtitles.firstWhere(
        (s) => s.codec == 'subrip' && !s.isExternal,
      );
      await service.selectSecondarySubtitle(srt.id);
      await eventually(
        () async => service.tracks.secondarySubtitleId == srt.id,
      );

      await service.selectAudioTrack(2);
      await eventually(() async => service.tracks.audioId == 2);

      await service.setSubtitleDelay(const Duration(milliseconds: 1500));
      await eventually(
        () async =>
            service.tracks.subtitleDelay == const Duration(milliseconds: 1500),
      );
      await service.setAudioDelay(const Duration(milliseconds: -200));
      await eventually(
        () async =>
            service.tracks.audioDelay == const Duration(milliseconds: -200),
      );
    });

    test('sub-add loads and selects an external file', () async {
      await openFilm();
      final before = service.tracks.subtitles.length;
      await service.addSubtitle(p.join(media, 'extra.srt'));
      await eventually(
        () async => service.tracks.subtitles.length == before + 1,
      );
      final added = service.tracks.subtitles.last;
      expect(added.isExternal, isTrue);
      await eventually(() async => service.tracks.subtitleId == added.id);
    });

    test('auto-load can be turned off', () async {
      await service.setAutoLoadSubtitles(enabled: false);
      await service.open(p.join(media, 'The.Test.Film.2019.1080p.mkv'));
      await waitFor((s) => s.isPlaying);
      await eventually(() async => service.tracks.subtitles.length >= 2);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(service.tracks.subtitles.where((s) => s.isExternal), isEmpty);
    });
  });

  test('subtitle style options are accepted by mpv', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await service.applySubtitleStyle(
      const SubtitleStyle(size: 60, position: 90, backgroundBox: true),
    );
    expect(await prop('sub-font-size'), startsWith('60'));
    expect(await prop('sub-pos'), startsWith('90'));
    final borderStyle = await prop('sub-border-style');
    if (borderStyle == null || borderStyle.isEmpty) {
      // libmpv < 0.38: the box is drawn with the shadow.
      expect(await prop('sub-shadow-offset'), startsWith('4'));
    } else {
      expect(borderStyle, 'opaque-box');
    }
  });

  test('aspect override and rotation are accepted by mpv', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await service.setAspectOverride('4:3');
    await eventually(
      () async => (await prop('video-aspect-override'))!.startsWith('1.333'),
    );
    await service.setRotation(90);
    expect(await prop('video-rotate'), '90');
  });

  test('media info has the main fields', () async {
    await service.open(p.join(media, 'The.Test.Film.2019.1080p.mkv'));
    await waitFor((s) => s.isPlaying && s.videoWidth != null);
    final info = await service.mediaInfo();
    expect(info['file-format'], anyOf(contains('mkv'), contains('matroska')));
    expect(info['video-codec'], contains('264'));
    expect(info['video-params/w'], '1920');
    expect(info['audio-params/channel-count'], isNotNull);
  });

  test(
    'completion fires once at the end',
    timeout: const Timeout(Duration(seconds: 60)),
    () async {
      final ends = <String>[];
      final sub = service.completions.listen(ends.add);
      await service.open(p.join(media, 'clip.mp4'));
      await waitFor((s) => s.isPlaying);
      await service.seek(const Duration(seconds: 7));
      await waitFor((s) => s.isCompleted, timeout: const Duration(seconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      expect(ends, hasLength(1));
      expect(service.state.status, PlaybackStatus.completed);
    },
  );

  test('chapters are listed and next chapter jumps', () async {
    await service.open(p.join(media, 'chapters.mkv'));
    await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
    await eventually(() async => service.tracks.chapters.length == 2);
    expect(service.tracks.chapters.map((c) => c.title), [
      'Opening',
      'The Heist',
    ]);
    await service.chapterBy(1);
    await waitFor((s) => s.position >= const Duration(seconds: 3));
    await eventually(() async => service.tracks.chapterIndex == 1);
  });

  test('preview thumbnails are rendered by a second mpv and cached', () async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_prev');
    addTearDown(() => dir.deleteSync(recursive: true));
    final t = PreviewThumbnailer(cacheDir: dir);
    addTearDown(t.dispose);
    final file = p.join(media, 'clip.mp4');
    const length = Duration(seconds: 8);
    final a = await t.frameAt(file, const Duration(seconds: 5), length);
    expect(a, isNotNull);
    final bytes = File(a!).readAsBytesSync();
    expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG');
    final b = await t.frameAt(file, const Duration(seconds: 2), length);
    expect(b, isNot(a));
    // Cached: same path straight away.
    expect(await t.frameAt(file, const Duration(seconds: 5), length), a);
  });

  test('A-B loop and frame stepping in mpv', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying && s.duration > Duration.zero);
    await service.seek(const Duration(seconds: 2));
    await waitFor((s) => s.position >= const Duration(seconds: 2));
    await service.cycleLoop();
    await waitFor((s) => s.position >= const Duration(seconds: 3));
    await service.cycleLoop();
    await eventually(() async => service.tracks.loopB != null);
    // Playback stays inside A–B.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(service.state.position, lessThan(const Duration(seconds: 5)));
    await service.clearLoop();
    await service.pause();
    final before = double.parse((await prop('time-pos'))!);
    await service.frameStep();
    await eventually(
      () async => double.parse((await prop('time-pos'))!) > before,
    );
  });

  test('FFmpeg extracts an embedded text track for translation', () async {
    await service.open(p.join(media, 'The.Test.Film.2019.1080p.mkv'));
    await waitFor((s) => s.isPlaying);
    await eventually(() async => service.tracks.subtitles.length >= 2);
    final srt = service.tracks.subtitles.firstWhere(
      (t) => t.codec == 'subrip' && !t.isExternal,
    );
    final cues = await const DefaultSubtitleExtractor().cues(
      p.join(media, 'The.Test.Film.2019.1080p.mkv'),
      srt,
      service.tracks.subtitles,
    );
    expect(cues.single.text, 'Hello from the embedded English track');
  });

  group('network streams over HTTP', () {
    late HttpServer server;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        ..listen((req) async {
          final path = req.uri.path;
          if (path.startsWith('/private/') &&
              req.headers.value('Authorization') != 'Basic bWU6cHc=') {
            req.response.statusCode = 401;
            await req.response.close();
            return;
          }
          final file = File(
            p.join(media, path.replaceFirst('/private', '').substring(1)),
          );
          if (!file.existsSync()) {
            req.response.statusCode = 404;
            await req.response.close();
            return;
          }
          req.response.contentLength = file.lengthSync();
          await req.response.addStream(file.openRead());
          await req.response.close();
        });
    });
    tearDown(() => server.close(force: true));

    String url(String path) => 'http://127.0.0.1:${server.port}/$path';

    for (final path in ['hls.m3u8', 'dash/manifest.mpd']) {
      test(path, () async {
        await service.open(url(path));
        final s = await waitFor(
          (s) => s.duration > Duration.zero && s.isPlaying,
        );
        expect(s.status, PlaybackStatus.playing);
      });
    }

    test('a protected stream plays only with the login header', () async {
      await service.open(url('private/clip.mp4'));
      await waitFor((s) => s.status == PlaybackStatus.error);
      service.setSourceHeaders(url('private/clip.mp4'), [
        'Authorization: Basic bWU6cHc=',
      ]);
      await service.open(url('private/clip.mp4'));
      final s = await waitFor((s) => s.duration > Duration.zero);
      expect(s.errorMessage, isNull);
    });
  });

  test('video quality and audio effects are accepted by mpv', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    final shader = File(p.absolute('assets/shaders/sharpen.glsl')).path;
    await service.applyVideoPreset(VideoPreset.sharpen, shaderPath: shader);
    expect(await prop('scale'), 'ewa_lanczossharp');
    expect(await prop('glsl-shaders'), contains('sharpen.glsl'));
    await service.setToneMapping('hable');
    expect(await prop('tone-mapping'), 'hable');
    await service.setDeband(enabled: true);
    expect(await prop('deband'), 'yes');
    await service.setHardwareDecoding('no');
    expect(await prop('hwdec'), 'no');
    await service.setEqualizer(Equalizer.presets['Rock']!);
    await service.setNormalization(Normalization.dynamic);
    await eventually(() async {
      final af = await prop('af') ?? '';
      return af.contains('equalizer') && af.contains('dynaudnorm');
    });
    // Still playing with the filters in place.
    final at = service.state.position;
    await waitFor((s) => s.position > at);
    await service.setEqualizer(Equalizer.presets['Flat']!);
    await eventually(
      () async => !(await prop('af') ?? '').contains('equalizer'),
    );
  });

  test('a Lua user script runs and talks back through user-data', () async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_lua');
    addTearDown(() => dir.deleteSync(recursive: true));
    final script = File(p.join(dir.path, 'hello.lua'))
      ..writeAsStringSync('''
mp.register_event("file-loaded", function()
  mp.set_property("user-data/kyndrel/osd", "Loaded " .. mp.get_property("filename"))
end)
mp.register_script_message("kyndrel-ping", function(x)
  mp.set_property("user-data/kyndrel/osd", "pong " .. x)
end)
''');
    final messages = <String>[];
    service.scriptOsd.listen(messages.add);
    await service.loadScript(script.path);
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await eventually(() async => messages.contains('Loaded clip.mp4'));
    await service.scriptMessage(['kyndrel-ping', '42']);
    await eventually(() async => messages.contains('pong 42'));
  });

  test('track list types', () {
    expect(MediaTrackType.values, hasLength(3));
  });
}
