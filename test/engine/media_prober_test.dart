@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/media_prober.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Task 7.3 with the real libmpv: details and thumbnails for the library.
///   scripts/make_test_media.sh && flutter test -t engine --run-skipped
void main() {
  final media = p.absolute('test_media/generated');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  });

  late Directory cache;
  late PreviewThumbnailer previews;
  late MpvMediaProber prober;
  setUp(() {
    cache = Directory.systemTemp.createTempSync('kyndrel_probe');
    previews = PreviewThumbnailer(cacheDir: cache);
    prober = MpvMediaProber(previews: previews);
  });
  tearDown(() async {
    await prober.dispose().timeout(const Duration(seconds: 20));
    await previews.dispose().timeout(const Duration(seconds: 20));
    cache.deleteSync(recursive: true);
  });

  test('a video: length, size, codecs and a frame', () async {
    final clip = p.join(media, 'clip.mp4');
    final d = (await prober.probe(clip))!;
    expect(d.duration!.inSeconds, inInclusiveRange(7, 8));
    expect((d.width, d.height), (1280, 720));
    expect(d.videoCodec, contains('h264'));
    expect(d.audioCodec, contains('aac'));
    expect(d.hasCover, isFalse);
    final thumb = await prober.thumbnail(
      clip,
      MediaKind.video,
      duration: d.duration,
    );
    expect(File(thumb!).readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);
  });

  test('a folder picture counts as the cover', () async {
    final d = (await prober.probe(p.join(media, 'plain.flac')))!;
    expect(d.hasCover, isTrue);
  });

  test('a song: tags, no video size, and its cover', () async {
    final song = p.join(media, 'song.mp3');
    final d = (await prober.probe(song))!;
    expect(d.title, 'Night Drive');
    expect(d.artist, 'Kyndrel Tests');
    expect(d.album, 'Test Tones');
    expect(d.trackNo, 3);
    expect(d.width, isNull);
    expect(d.hasCover, isTrue);
    final cover = await prober.thumbnail(
      song,
      MediaKind.audio,
      duration: d.duration,
    );
    expect(File(cover!).readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);
  });

  test('a song without a cover gets no picture, quickly', () async {
    // Alone in a folder: next to cover.png, mpv would use that as its cover.
    final plain = p.join(cache.path, 'plain.flac');
    File(p.join(media, 'plain.flac')).copySync(plain);
    final d = (await prober.probe(plain))!;
    expect(d.title, 'Plain Tone');
    expect(d.hasCover, isFalse);
    expect(
      await prober.thumbnail(plain, MediaKind.audio, hasCover: d.hasCover),
      isNull,
    );
  });

  test('not a media file: no details', () async {
    expect(await prober.probe(p.join(media, 'broken.mkv')), isNull);
  });
}
