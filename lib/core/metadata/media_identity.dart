import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:kyndrel/core/utils/media_title.dart';

/// Which film or episode a file is, as online databases know it (Phase 9):
/// the IMDb id (subtitle and skip-segment databases use it, as in Harbor)
/// and, for anime, the MyAnimeList id (AniSkip).
@immutable
class MediaIdentity {
  const new({
    required this.title,
    this.year,
    this.imdbId,
    this.series = false,
    this.season,
    this.episode,
    this.malId,
  });

  final String title;
  final int? year;

  /// `tt0133093`, or null when the title wasn't found.
  final String? imdbId;
  final bool series;
  final int? season;
  final int? episode;

  /// MyAnimeList id, looked up only when asked ([MediaIdentifier.malIdOf]).
  final int? malId;
}

/// Finds [MediaIdentity]s with Stremio's public Cinemeta catalogue (no key,
/// the source Harbor uses) and, for anime, Jikan (MyAnimeList, no key).
/// Answers are remembered for the session; failures make no noise.
class MediaIdentifier {
  new({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final _cache = <String, Future<MediaIdentity?>>{};
  final _mal = <String, Future<int?>>{};

  static const cinemeta = 'https://v3-cinemeta.strem.io';
  static const jikan = 'https://api.jikan.moe/v4';
  static const timeout = Duration(seconds: 8);

  /// The file name tells the title, year, season and episode.
  Future<MediaIdentity?> identify(String source) {
    final ep = parseEpisode(source);
    final parsed = parseMediaTitle(source);
    final title = ep?.show ?? parsed.title;
    if (title.trim().length < 2) return Future.value();
    final key = '${ep != null}|${title.toLowerCase()}|${parsed.year}';
    return _cache
        .putIfAbsent(key, () => _lookup(title, parsed.year, series: ep != null))
        .then(
          (id) => id == null
              ? null
              : MediaIdentity(
                  title: id.title,
                  year: id.year,
                  imdbId: id.imdbId,
                  series: id.series,
                  season: ep?.season,
                  episode: ep?.episode,
                ),
        );
  }

  Future<MediaIdentity?> _lookup(
    String title,
    int? year, {
    required bool series,
  }) async {
    final type = series ? 'series' : 'movie';
    final q = Uri.encodeComponent(title);
    try {
      final r = await _http
          .get(Uri.parse('$cinemeta/catalog/$type/top/search=$q.json'))
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      final metas =
          (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['metas'] as List? ??
          const [];
      Map<dynamic, dynamic>? best;
      for (final m in metas.whereType<Map<dynamic, dynamic>>()) {
        final id = m['imdb_id'] ?? m['id'];
        if (id is! String || !id.startsWith('tt')) continue;
        final y = int.tryParse(
          '${m['releaseInfo'] ?? m['year'] ?? ''}'
              .split(RegExp('[^0-9]'))
              .first,
        );
        if (year == null || y == year) {
          best = m;
          break;
        }
        best ??= m;
      }
      if (best == null) return null;
      return MediaIdentity(
        title: '${best['name'] ?? title}',
        year: int.tryParse(
          '${best['releaseInfo'] ?? ''}'.split(RegExp('[^0-9]')).first,
        ),
        imdbId: '${best['imdb_id'] ?? best['id']}',
        series: series,
      );
    } on Object {
      return null;
    }
  }

  /// The MyAnimeList id of the show called [title], for AniSkip.
  Future<int?> malIdOf(String title) =>
      _mal.putIfAbsent(title.toLowerCase(), () async {
        try {
          final r = await _http
              .get(
                Uri.parse(
                  '$jikan/anime?q=${Uri.encodeQueryComponent(title)}&limit=1',
                ),
              )
              .timeout(timeout);
          if (r.statusCode != 200) return null;
          final data = (jsonDecode(r.body) as Map)['data'] as List?;
          final first = data?.firstOrNull;
          return first is Map ? first['mal_id'] as int? : null;
        } on Object {
          return null;
        }
      });

  void close() => _http.close();
}

final mediaIdentifierProvider = Provider<MediaIdentifier>((ref) {
  final m = MediaIdentifier();
  ref.onDispose(m.close);
  return m;
});
