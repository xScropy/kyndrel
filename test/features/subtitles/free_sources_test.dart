import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/core/metadata/media_identity.dart';
import 'package:kyndrel/core/subtitles/release_match.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/free_sources.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/opensubtitles_client.dart';
import 'package:kyndrel/features/subtitles/subtitle_search_controller.dart';

/// Task 9.6: keyless subtitle sources and Harbor's ranking.
void main() {
  test('release names: episode, group, source, resolution', () {
    final video = ReleaseTags.parse(
      'Show.S02E05.1080p.WEB-DL.DDP5.1.H.264-FLUX.mkv',
    );
    expect(video.season, 2);
    expect(video.episode, 5);
    expect(video.group, 'FLUX');
    expect(video.source, SourceClass.webdl);
    expect(video.resolution, '1080p');

    final same = ReleaseAffinity.of(video, 'Show.S02E05.1080p.WEB-DL-FLUX');
    expect(same.confidence, MatchConfidence.high);
    expect(same.percent, greaterThanOrEqualTo(75));

    final otherEpisode = ReleaseAffinity.of(video, 'Show.S02E06.WEB-DL');
    expect(otherEpisode.confidence, MatchConfidence.incompatible);
    expect(otherEpisode.percent, lessThan(20));

    final bluray = ReleaseAffinity.of(video, 'Show.S02E05.BluRay.x264');
    expect(bluray.confidence, MatchConfidence.incompatible);
    final webrip = ReleaseAffinity.of(video, 'Show.S02E05.WEBRip');
    expect(webrip.confidence, MatchConfidence.medium);
  });

  test("ranking: hash, then the user's languages, then the fit", () {
    SubtitleResult r(String lang, String release, {bool hash = false}) =>
        SubtitleResult(
          fileId: release.hashCode,
          language: lang,
          release: release,
          fileName: '$release.srt',
          hashMatch: hash,
        );
    final ranked = rankSubtitles(
      [
        r('en', 'Film.2019.1080p.BluRay-EVO'),
        r('ar', 'Film.2019.720p.WEB-DL'),
        r('ar', 'Film.2019.1080p.BluRay-EVO'),
        r('en', 'Film.2019.DVDRip', hash: true),
      ],
      videoName: 'Film.2019.1080p.BluRay.x264-EVO.mkv',
      languages: ['ar', 'en'],
    );
    expect(
      [for (final x in ranked) '${x.language} ${x.release}'],
      [
        'en Film.2019.DVDRip',
        'ar Film.2019.1080p.BluRay-EVO',
        'ar Film.2019.720p.WEB-DL',
        'en Film.2019.1080p.BluRay-EVO',
      ],
    );
    expect(ranked.first.matchPercent, 100);
    expect(ranked[1].matchPercent, greaterThanOrEqualTo(75));
    expect(ranked[1].matchReason, 'same release group EVO');
  });

  test(
    'the OpenSubtitles addon and Wyzie, merged; downloads unpacked',
    () async {
      final dir = Directory.systemTemp.createTempSync('kyndrel_free');
      addTearDown(() => dir.deleteSync(recursive: true));
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nمرحبا\n';
      final zip = ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.bytes('a/film.ar.srt', utf8.encode(srt))),
      );
      final asked = <String>[];
      final client = MockClient((req) async {
        final u = req.url.toString();
        asked.add(u);
        if (u.startsWith(FreeSubtitleSources.openSubtitlesAddon)) {
          expect(req.url.path, '/subtitles/series/tt1234:1:2.json');
          return http.Response(
            jsonEncode({
              'subtitles': [
                {'id': '1', 'url': 'https://dl/os1', 'lang': 'ara'},
                {'id': '2', 'url': 'https://dl/os2', 'lang': 'fre'},
              ],
            }),
            200,
          );
        }
        if (u.startsWith(FreeSubtitleSources.wyzie)) {
          expect(req.url.queryParameters['id'], 'tt1234');
          expect(req.url.queryParameters['language'], 'ar,en');
          return http.Response(
            jsonEncode([
              {
                'url': 'https://dl/wz',
                'language': 'ar',
                'release': 'Show.S01E02.WEB',
                'format': 'srt',
                'isHearingImpaired': true,
                'downloads': 12,
              },
              {'url': 'https://dl/os1', 'language': 'ar'},
            ]),
            200,
          );
        }
        if (u == 'https://dl/os1') {
          return http.Response.bytes(gzip.encode(utf8.encode(srt)), 200);
        }
        if (u == 'https://dl/wz') return http.Response.bytes(zip, 200);
        return http.Response('', 404);
      });
      final sources = FreeSubtitleSources(cacheDir: dir, client: client);
      final results = await sources.search(
        languages: ['ar', 'en'],
        imdbId: 'tt1234',
        season: 1,
        episode: 2,
      );
      expect(
        [for (final r in results) (r.provider, r.language)],
        [('OpenSubtitles (free)', 'ar'), ('Wyzie', 'ar')],
      );
      expect(results[1].hearingImpaired, isTrue);
      expect(results[1].downloadCount, 12);

      final gz = await sources.download(results[0]);
      expect(utf8.decode(gz.readAsBytesSync()), srt);
      final zipped = await sources.download(results[1]);
      expect(utf8.decode(zipped.readAsBytesSync()), srt);
    },
  );

  test('a title is looked up on Cinemeta; the year picks the film', () async {
    final client = MockClient((req) async {
      expect(
        req.url.toString(),
        endsWith('/catalog/movie/top/search=The%20Matrix.json'),
      );
      return http.Response(
        jsonEncode({
          'metas': [
            {'id': 'tt9999', 'name': 'The Matrix', 'releaseInfo': '2021'},
            {'id': 'tt0133093', 'name': 'The Matrix', 'releaseInfo': '1999'},
          ],
        }),
        200,
      );
    });
    final id = await MediaIdentifier(client: client)
        .identify('/films/The.Matrix.1999.1080p.BluRay.mkv');
    expect(id?.imdbId, 'tt0133093');
    expect(id?.series, isFalse);
  });
}
