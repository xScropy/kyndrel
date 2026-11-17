import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/movie_hash.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/opensubtitles_client.dart';

Map<String, Object?> _item(
  int fileId, {
  String lang = 'en',
  int downloads = 10,
  bool hashMatch = false,
}) => {
  'attributes': {
    'language': lang,
    'release': 'Release $fileId',
    'ratings': 7.5,
    'download_count': downloads,
    'hearing_impaired': false,
    'moviehash_match': hashMatch,
    'files': [
      {'file_id': fileId, 'file_name': 'sub$fileId.srt'},
    ],
  },
};

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kyndrel_os'));
  tearDown(() => tmp.deleteSync(recursive: true));

  OpenSubtitlesClient client(MockClient http, {String key = 'k'}) =>
      OpenSubtitlesClient(
        apiKey: key,
        cacheDir: tmp,
        httpClient: http,
        minInterval: Duration.zero,
      );

  test('movie hash matches the reference algorithm', () async {
    final f = File('${tmp.path}/sample.bin')
      ..writeAsBytesSync(List.generate(300000, (i) => (i * 7 + 3) % 256));
    expect(await computeMovieHash(f), '60a0df1f5fa453e0');
    final small = File('${tmp.path}/small.bin')..writeAsBytesSync([1, 2, 3]);
    expect(await computeMovieHash(small), isNull);
  });

  test('search sends sorted lower-case parameters and auth headers', () async {
    late http.Request seen;
    final c = client(
      MockClient((r) async {
        seen = r;
        return http.Response(jsonEncode({'data': <Object>[]}), 200);
      }),
    );
    await c.search(
      const SubtitleQuery(
        movieHash: 'abc',
        text: 'The Matrix',
        year: 1999,
        languages: ['FR', 'en'],
      ),
    );
    expect(seen.url.path, '/api/v1/subtitles');
    expect(
      seen.url.query,
      'languages=en%2Cfr&moviehash=abc&query=the+matrix&year=1999',
    );
    expect(seen.headers['Api-Key'], 'k');
    expect(seen.headers['User-Agent'], startsWith('Kyndrel'));
  });

  test('results are parsed and ranked: hash matches, then downloads', () async {
    final c = client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              _item(1, downloads: 50),
              _item(2, downloads: 5, hashMatch: true),
              _item(3, lang: 'ar', downloads: 500),
            ],
          }),
          200,
        ),
      ),
    );
    final r = await c.search(const SubtitleQuery(text: 'x'));
    expect(r.map((e) => e.fileId), [2, 3, 1]);
    expect(r.first.hashMatch, isTrue);
    expect(r[1].language, 'ar');
    expect(r[1].rating, 7.5);
  });

  test('identical searches are served from the cache', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'data': <Object>[]}), 200);
      }),
    );
    await c.search(const SubtitleQuery(text: 'a'));
    await c.search(const SubtitleQuery(text: 'a'));
    await c.search(const SubtitleQuery(text: 'b'));
    expect(calls, 2);
  });

  test('missing API key fails before any request', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      key: '',
    );
    await expectLater(
      c.search(const SubtitleQuery(text: 'a')),
      throwsA(isA<MissingApiKey>()),
    );
    expect(calls, 0);
  });

  test('429 is reported with Retry-After and blocks further calls', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        return http.Response('', 429, headers: {'retry-after': '30'});
      }),
    );
    await expectLater(
      c.search(const SubtitleQuery(text: 'a')),
      throwsA(
        isA<RateLimited>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
    await expectLater(
      c.search(const SubtitleQuery(text: 'b')),
      throwsA(isA<RateLimited>()),
    );
    expect(calls, 1);
  });

  test('bad key and quota errors are explained', () async {
    final c401 = client(MockClient((_) async => http.Response('', 401)));
    await expectLater(
      c401.search(const SubtitleQuery(text: 'a')),
      throwsA(
        isA<RequestFailed>().having(
          (e) => e.message,
          'message',
          contains('key'),
        ),
      ),
    );
    final c406 = client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'You have downloaded your allowed 5 subtitles',
          }),
          406,
        ),
      ),
    );
    await expectLater(
      c406.download(
        const SubtitleResult(
          fileId: 9,
          language: 'en',
          release: 'r',
          fileName: 'a.srt',
        ),
      ),
      throwsA(isA<QuotaExceeded>()),
    );
  });

  test('download fetches the link once and reuses the cached file', () async {
    var posts = 0;
    var gets = 0;
    final c = client(
      MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          expect(jsonDecode(r.body), {'file_id': 42});
          return http.Response(
            jsonEncode({'link': 'https://dl.example.com/42.srt'}),
            200,
          );
        }
        gets++;
        return http.Response('1\n00:00:01,000 --> 00:00:02,000\nHi\n', 200);
      }),
    );
    const result = SubtitleResult(
      fileId: 42,
      language: 'en',
      release: 'r',
      fileName: 'movie.srt',
    );
    final f1 = await c.download(result);
    final f2 = await c.download(result);
    expect(f1.path, f2.path);
    expect(f1.path, endsWith('42.srt'));
    expect(f1.readAsStringSync(), contains('Hi'));
    expect((posts, gets), (1, 1));
  });
}
