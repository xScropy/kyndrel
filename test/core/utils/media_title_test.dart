import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/utils/media_title.dart';

void main() {
  group('parseMediaTitle', () {
    final cases = <String, (String, int?, String?)>{
      '/films/The.Matrix.1999.1080p.BluRay.x264.mkv': (
        'The Matrix',
        1999,
        null,
      ),
      r'C:\Videos\Inception (2010) [2160p].mkv': ('Inception', 2010, null),
      'Blade_Runner_2049_2017_WEB-DL.mp4': ('Blade Runner 2049', 2017, null),
      '2001.A.Space.Odyssey.1968.mkv': ('2001 A Space Odyssey', 1968, null),
      'Show.Name.S01E02.720p.HDTV.mkv': ('Show Name', null, 'S01E02'),
      'Another Show 2x05 Title.avi': ('Another Show', null, 'S02E05'),
      'Series.2019.S03E10.WEBRip.mkv': ('Series', 2019, 'S03E10'),
      'holiday-video.mp4': ('holiday-video', null, null),
      'https://cdn.example.com/hls/My.Stream.2021/index.m3u8?t=1': (
        'index',
        null,
        null,
      ),
      'https://example.com/movies/Big.Buck.Bunny.2008.mp4': (
        'Big Buck Bunny',
        2008,
        null,
      ),
    };
    for (final e in cases.entries) {
      test(e.key, () {
        final t = parseMediaTitle(e.key);
        expect((t.title, t.year, t.episode), e.value);
      });
    }
  });

  group('qualityLabel', () {
    test('standard sizes', () {
      expect(qualityLabel(640, 480), '480P');
      expect(qualityLabel(854, 480), '480P');
      expect(qualityLabel(1280, 720), '720P');
      expect(qualityLabel(1920, 1080), '1080P');
      expect(qualityLabel(2560, 1440), '1440P');
      expect(qualityLabel(3840, 2160), '4K');
      expect(qualityLabel(640, 360), '360P');
    });

    test('cropped scope films use the width', () {
      expect(qualityLabel(1920, 800), '1080P');
      expect(qualityLabel(3840, 1600), '4K');
      expect(qualityLabel(1280, 536), '720P');
    });

    test('unknown size', () {
      expect(qualityLabel(null, 720), isNull);
      expect(qualityLabel(0, 0), isNull);
    });
  });
}
