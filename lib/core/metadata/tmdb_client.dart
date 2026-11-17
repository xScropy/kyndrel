import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kyndrel/core/metadata/media_details.dart';

class TmdbException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal TMDB API v3 client. Accepts a v3 API key or a v4 read access
/// token (sent as a bearer token).
class TmdbClient {
  new({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static final Uri baseUri = Uri.parse('https://api.themoviedb.org/3/');

  final String apiKey;
  final http.Client _http;

  bool get _isBearer => apiKey.startsWith('eyJ');

  Future<Map<String, Object?>> _get(
    String path,
    Map<String, String> query,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw const TmdbException('Add a TMDB API key in Settings.');
    }
    final uri = baseUri
        .resolve(path)
        .replace(
          queryParameters: {...query, if (!_isBearer) 'api_key': apiKey},
        );
    final http.Response r;
    try {
      r = await _http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (_isBearer) 'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw TmdbException('TMDB is unreachable: $e');
    }
    if (r.statusCode == 401) {
      throw const TmdbException('TMDB rejected the API key.');
    }
    if (r.statusCode == 429) {
      throw const TmdbException('TMDB is busy. Try again shortly.');
    }
    if (r.statusCode != 200) {
      throw TmdbException('TMDB error ${r.statusCode}.');
    }
    return (jsonDecode(r.body) as Map).cast<String, Object?>();
  }

  static int? _year(Object? date) {
    if (date is! String || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  Future<List<MediaDetails>> searchMovies(String query, {int? year}) async {
    final j = await _get('search/movie', {
      'query': query,
      if (year != null) 'year': '$year',
    });
    return [
      for (final r
          in (j['results'] as List? ?? const []).cast<Map<String, Object?>>())
        MediaDetails(
          kind: MediaKind.movie,
          tmdbId: (r['id'] as num?)?.toInt(),
          title: r['title'] as String? ?? '',
          year: _year(r['release_date']),
          overview: r['overview'] as String?,
          posterPath: r['poster_path'] as String?,
        ),
    ];
  }

  Future<List<MediaDetails>> searchShows(String query, {int? year}) async {
    final j = await _get('search/tv', {
      'query': query,
      if (year != null) 'first_air_date_year': '$year',
    });
    return [
      for (final r
          in (j['results'] as List? ?? const []).cast<Map<String, Object?>>())
        MediaDetails(
          kind: MediaKind.episode,
          tmdbId: (r['id'] as num?)?.toInt(),
          title: r['name'] as String? ?? '',
          year: _year(r['first_air_date']),
          overview: r['overview'] as String?,
          posterPath: r['poster_path'] as String?,
        ),
    ];
  }

  /// Fills in episode name and still for [show] (from [searchShows]).
  Future<MediaDetails> episode(
    MediaDetails show,
    int season,
    int episode,
  ) async {
    final j = await _get(
      'tv/${show.tmdbId}/season/$season/episode/$episode',
      {},
    );
    return MediaDetails(
      kind: MediaKind.episode,
      tmdbId: show.tmdbId,
      title: show.title,
      year: show.year,
      posterPath: show.posterPath,
      season: season,
      episode: episode,
      episodeTitle: j['name'] as String?,
      overview: j['overview'] as String? ?? show.overview,
      stillPath: j['still_path'] as String?,
    );
  }

  void close() => _http.close();
}
