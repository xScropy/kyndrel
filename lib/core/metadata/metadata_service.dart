import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kyndrel/core/metadata/media_details.dart';
import 'package:kyndrel/core/metadata/tmdb_client.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:kyndrel/core/utils/media_title.dart';

/// Looks up and caches what a file is (task 3.4). Lookups are cached in the
/// database; a manual choice is never overwritten.
class MetadataService {
  new(this._db, this._client);

  final KyndrelDatabase _db;
  final TmdbClient? _client;

  Future<MediaDetails?> cached(String source) async {
    final row = await (_db.select(
      _db.mediaMetadata,
    )..where((r) => r.source.equals(source))).getSingleOrNull();
    if (row == null) return null;
    return MediaDetails.fromJson(
      (jsonDecode(row.json) as Map).cast<String, Object?>(),
    );
  }

  /// Cached details, or a TMDB lookup when a key is set. Null if unknown.
  Future<MediaDetails?> lookup(String source) async {
    final hit = await cached(source);
    if (hit != null) return hit;
    final client = _client;
    if (client == null) return null;
    final details = await _fetch(client, source);
    if (details != null) await _store(source, details, manual: false);
    return details;
  }

  Future<MediaDetails?> _fetch(TmdbClient client, String source) async {
    final ep = parseEpisode(source);
    final title = parseMediaTitle(source);
    if (ep != null) {
      final shows = await client.searchShows(title.title, year: title.year);
      if (shows.isEmpty) return null;
      try {
        return await client.episode(shows.first, ep.season, ep.episode);
      } on TmdbException {
        return MediaDetails(
          kind: MediaKind.episode,
          tmdbId: shows.first.tmdbId,
          title: shows.first.title,
          year: shows.first.year,
          posterPath: shows.first.posterPath,
          season: ep.season,
          episode: ep.episode,
        );
      }
    }
    final movies = await client.searchMovies(title.title, year: title.year);
    if (movies.isEmpty) return null;
    return movies.firstWhere(
      (m) => title.year == null || m.year == title.year,
      orElse: () => movies.first,
    );
  }

  /// Candidates for the "Edit details" dialog.
  Future<List<MediaDetails>> search(
    String query, {
    required bool episode,
    int? year,
  }) async {
    final client = _client;
    if (client == null) {
      throw const TmdbException('Add a TMDB API key in Settings.');
    }
    return episode
        ? await client.searchShows(query, year: year)
        : await client.searchMovies(query, year: year);
  }

  /// The user picked [details] (or typed a title/year): store it for good.
  /// For a show picked for an episode file, fetches the episode name.
  Future<MediaDetails> setManual(String source, MediaDetails details) async {
    var d = details;
    final ep = parseEpisode(source);
    final client = _client;
    if (d.kind == MediaKind.episode &&
        ep != null &&
        d.tmdbId != null &&
        client != null) {
      try {
        d = await client.episode(d, ep.season, ep.episode);
      } on TmdbException {
        // Keep the show-level details.
      }
    }
    await _store(source, d, manual: true);
    return d;
  }

  Future<void> forget(String source) => (_db.delete(
    _db.mediaMetadata,
  )..where((r) => r.source.equals(source))).go();

  Future<void> _store(
    String source,
    MediaDetails d, {
    required bool manual,
  }) async {
    if (!manual) {
      final existing = await (_db.select(
        _db.mediaMetadata,
      )..where((r) => r.source.equals(source))).getSingleOrNull();
      if (existing?.manual ?? false) return;
    }
    await _db
        .into(_db.mediaMetadata)
        .insertOnConflictUpdate(
          MediaMetadataCompanion.insert(
            source: source,
            json: jsonEncode(d.toJson()),
            manual: Value(manual),
            updatedAt: DateTime.now(),
          ),
        );
  }
}

final tmdbClientProvider = Provider<TmdbClient?>((ref) {
  final key = ref.watch(settingsProvider.select((s) => s.tmdbApiKey)).trim();
  if (key.isEmpty) return null;
  final client = TmdbClient(apiKey: key);
  ref.onDispose(client.close);
  return client;
});

final metadataServiceProvider = Provider<MetadataService>(
  (ref) => MetadataService(
    ref.watch(databaseProvider),
    ref.watch(tmdbClientProvider),
  ),
);

/// Details for a source; null while unknown. Lookups never throw here.
final FutureProviderFamily<MediaDetails?, String> mediaDetailsProvider =
    FutureProvider.family<MediaDetails?, String>((ref, source) async {
      try {
        return await ref.watch(metadataServiceProvider).lookup(source);
      } on TmdbException {
        return null;
      } on Exception {
        return null;
      }
    });
