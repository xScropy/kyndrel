import 'package:flutter/foundation.dart';

enum MediaKind { movie, episode }

/// What TMDB (or the user) says a file is (task 3.4).
@immutable
class MediaDetails {
  const new({
    required this.kind,
    required this.title,
    this.tmdbId,
    this.year,
    this.overview,
    this.posterPath,
    this.season,
    this.episode,
    this.episodeTitle,
    this.stillPath,
  });

  factory fromJson(Map<String, Object?> j) => MediaDetails(
    kind: MediaKind.values.byName(j['kind'] as String? ?? 'movie'),
    title: j['title'] as String? ?? '',
    tmdbId: j['tmdbId'] as int?,
    year: j['year'] as int?,
    overview: j['overview'] as String?,
    posterPath: j['posterPath'] as String?,
    season: j['season'] as int?,
    episode: j['episode'] as int?,
    episodeTitle: j['episodeTitle'] as String?,
    stillPath: j['stillPath'] as String?,
  );

  final MediaKind kind;

  /// Movie title, or the show's name for an episode.
  final String title;
  final int? tmdbId;
  final int? year;
  final String? overview;

  /// TMDB image paths (`/abc.jpg`), see [imageUrl].
  final String? posterPath;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? stillPath;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String imageUrl(String path, {String size = 'w342'}) =>
      'https://image.tmdb.org/t/p/$size$path';

  String? get posterUrl => posterPath == null ? null : imageUrl(posterPath!);
  String? get stillUrl =>
      stillPath == null ? null : imageUrl(stillPath!, size: 'w300');

  /// `S01E02 · Pilot · 2019` style line under the title.
  String get subtitle => [
    if (season != null && episode != null)
      'S${_two(season!)}E${_two(episode!)}',
    ?episodeTitle,
    if (year != null) '$year',
  ].join(' · ');

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'tmdbId': tmdbId,
    'year': year,
    'overview': overview,
    'posterPath': posterPath,
    'season': season,
    'episode': episode,
    'episodeTitle': episodeTitle,
    'stillPath': stillPath,
  };

  MediaDetails copyWith({String? title, int? Function()? year}) => MediaDetails(
    kind: kind,
    title: title ?? this.title,
    tmdbId: tmdbId,
    year: year != null ? year() : this.year,
    overview: overview,
    posterPath: posterPath,
    season: season,
    episode: episode,
    episodeTitle: episodeTitle,
    stillPath: stillPath,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaDetails && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
