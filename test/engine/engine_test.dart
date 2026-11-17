@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
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

  tearDown(() => service.dispose());

  Future<PlaybackState> waitFor(
    bool Function(PlaybackState) test, {
    Duration timeout = const Duration(seconds: 15),
  }) => service.states.firstWhere(test).timeout(timeout);

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

  test('volume reaches 400 % and the limiter is added above 100 %', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await waitFor((s) => s.isPlaying);
    await service.setVolume(400);
    await eventually(() async => double.parse((await prop('volume'))!) == 400);
    expect(await prop('volume-max'), startsWith('400'));
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

  test('completion fires once at the end', () async {
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
  });

  test('track list types', () {
    expect(MediaTrackType.values, hasLength(3));
  });
}
