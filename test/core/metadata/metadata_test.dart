import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/core/metadata/media_details.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/metadata/tmdb_client.dart';
import 'package:kyndrel/core/storage/database.dart';

import '../../support/test_database.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

MockClient _tmdb(List<Uri> seen) => MockClient((r) async {
  seen.add(r.url);
  switch (r.url.path) {
    case '/3/search/movie':
      return _json({
        'results': [
          {
            'id': 1,
            'title': 'The Matrix Reloaded',
            'release_date': '2003-05-15',
          },
          {
            'id': 603,
            'title': 'The Matrix',
            'release_date': '1999-03-31',
            'poster_path': '/m.jpg',
            'overview': 'Neo',
          },
        ],
      });
    case '/3/search/tv':
      return _json({
        'results': [
          {
            'id': 1399,
            'name': 'Show Name',
            'first_air_date': '2011-04-17',
            'poster_path': '/s.jpg',
          },
        ],
      });
    case '/3/tv/1399/season/1/episode/2':
      return _json({'name': 'The Kingsroad', 'still_path': '/e.jpg'});
  }
  return http.Response('', 404);
});

void main() {
  late KyndrelDatabase db;
  late List<Uri> seen;
  setUp(() {
    db = testDatabase();
    seen = [];
  });
  tearDown(() => db.close());

  MetadataService service({String key = 'k'}) =>
      MetadataService(db, TmdbClient(apiKey: key, httpClient: _tmdb(seen)));

  test('movie lookup prefers the parsed year and is cached', () async {
    final s = service();
    final d = await s.lookup('/v/The.Matrix.1999.1080p.mkv');
    expect(d!.tmdbId, 603);
    expect(d.title, 'The Matrix');
    expect(d.year, 1999);
    expect(d.posterUrl, 'https://image.tmdb.org/t/p/w342/m.jpg');
    expect(seen.single.queryParameters, {
      'query': 'The Matrix',
      'year': '1999',
      'api_key': 'k',
    });
    await s.lookup('/v/The.Matrix.1999.1080p.mkv');
    expect(seen, hasLength(1));
  });

  test('episode lookup fetches the episode name', () async {
    final d = await service().lookup('/tv/Show.Name.S01E02.mkv');
    expect(d!.kind, MediaKind.episode);
    expect(d.title, 'Show Name');
    expect(d.episodeTitle, 'The Kingsroad');
    expect(d.subtitle, 'S01E02 · The Kingsroad · 2011');
    expect(d.stillUrl, contains('/e.jpg'));
  });

  test('v4 tokens are sent as a bearer header', () async {
    late http.Request req;
    final c = TmdbClient(
      apiKey: 'eyJhbGciOi.token',
      httpClient: MockClient((r) async {
        req = r;
        return _json({'results': <Object>[]});
      }),
    );
    await c.searchMovies('x');
    expect(req.headers['Authorization'], 'Bearer eyJhbGciOi.token');
    expect(req.url.queryParameters.containsKey('api_key'), isFalse);
  });

  test('a manual choice is never overwritten by lookups', () async {
    final s = service();
    await s.setManual(
      '/v/The.Matrix.1999.mkv',
      const MediaDetails(kind: MediaKind.movie, title: 'My Title', year: 2000),
    );
    final d = await s.lookup('/v/The.Matrix.1999.mkv');
    expect(d!.title, 'My Title');
    expect(seen, isEmpty);
    await s.forget('/v/The.Matrix.1999.mkv');
    expect((await s.lookup('/v/The.Matrix.1999.mkv'))!.title, 'The Matrix');
  });

  test('picking a show for an episode file fetches the episode', () async {
    final s = service();
    final shows = await s.search('Show Name', episode: true);
    final d = await s.setManual('/tv/Show.Name.S01E02.mkv', shows.first);
    expect(d.episodeTitle, 'The Kingsroad');
  });

  test('no key: no lookups, no errors', () async {
    final s = MetadataService(db, null);
    expect(await s.lookup('/v/a.mkv'), isNull);
    await expectLater(
      s.search('x', episode: false),
      throwsA(isA<TmdbException>()),
    );
  });

  test('bad key is reported', () async {
    final c = TmdbClient(
      apiKey: 'bad',
      httpClient: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      c.searchMovies('x'),
      throwsA(
        isA<TmdbException>().having((e) => e.message, 'm', contains('key')),
      ),
    );
  });
}
