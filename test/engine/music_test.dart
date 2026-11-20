@Tags(['engine'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Task 7.6 with the real libmpv: music is recognised, tags read and the
/// loudness measured.
///   scripts/make_test_media.sh && flutter test -t engine --run-skipped
void main() {
  final media = p.absolute('test_media/generated');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  });

  late PlayerService service;
  setUp(() async {
    service = PlayerService(MediaKitBackend(withVideo: false));
    await service.backend.setProperty('ao', 'null');
    await service.backend.setProperty('vo', 'null');
  });
  tearDown(() => service.dispose().timeout(const Duration(seconds: 20)));

  Future<void> eventually(Future<bool> Function() check) async {
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (!await check()) {
      if (DateTime.now().isAfter(end)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  test('a song with cover art is music, with its tags', () async {
    await service.open(p.join(media, 'song.mp3'));
    await eventually(() async => service.tracks.audio.isNotEmpty);
    expect(service.tracks.isAudioOnly, isTrue);
    final tags = await service.readTags();
    expect(tags.title, 'Night Drive');
    expect(tags.artist, 'Kyndrel Tests');
    expect(tags.album, 'Test Tones');
  });

  test('a video is not music', () async {
    await service.open(p.join(media, 'clip.mp4'));
    await eventually(() async => service.tracks.video.isNotEmpty);
    expect(service.tracks.isAudioOnly, isFalse);
  });

  test('the level meter follows the sound', () async {
    await service.setLevelMeter(enabled: true);
    await service.open(p.join(media, 'song.mp3'));
    await eventually(() async => service.state.isPlaying);
    final levels = await service
        .levels(interval: const Duration(milliseconds: 100))
        .skip(3)
        .take(5)
        .toList();
    // The test tone sits around -21 dB RMS: about 0.65 here.
    expect(
      levels.map((l) => l.rms).reduce((a, b) => a > b ? a : b),
      greaterThan(0.5),
    );
    await service.setLevelMeter(enabled: false);
    expect(await service.backend.getProperty('af'), isNot(contains('kviz')));
  });
}
