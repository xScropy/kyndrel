import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/metadata/media_identity.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/subtitles/release_match.dart';
import 'package:kyndrel/core/subtitles/subtitle_prepare.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/free_sources.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/movie_hash.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/opensubtitles_client.dart';
import 'package:path/path.dart' as p;

enum SearchStatus { idle, searching, done, failed }

@immutable
class SubtitleSearchState {
  const new({
    this.status = SearchStatus.idle,
    this.results = const [],
    this.message,
    this.source,
    this.queryText = '',
    this.applyingFileId,
    this.appliedFileIds = const {},
  });

  final SearchStatus status;
  final List<SubtitleResult> results;
  final String? message;

  /// The media the results belong to.
  final String? source;
  final String queryText;
  final int? applyingFileId;
  final Set<int> appliedFileIds;

  SubtitleSearchState copyWith({
    SearchStatus? status,
    List<SubtitleResult>? results,
    String? Function()? message,
    String? source,
    String? queryText,
    int? Function()? applyingFileId,
    Set<int>? appliedFileIds,
  }) {
    return SubtitleSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      message: message != null ? message() : this.message,
      source: source ?? this.source,
      queryText: queryText ?? this.queryText,
      applyingFileId: applyingFileId != null
          ? applyingFileId()
          : this.applyingFileId,
      appliedFileIds: appliedFileIds ?? this.appliedFileIds,
    );
  }
}

final openSubtitlesClientProvider = Provider<OpenSubtitlesClient>((ref) {
  final key = ref.watch(settingsProvider.select((s) => s.openSubtitlesApiKey));
  final client = OpenSubtitlesClient(
    apiKey: key,
    cacheDir: Directory(
      p.join(ref.watch(appCacheDirProvider).path, 'subtitles'),
    ),
  );
  ref.onDispose(client.close);
  return client;
});

final freeSubtitleSourcesProvider = Provider<FreeSubtitleSources>((ref) {
  final sources = FreeSubtitleSources(
    cacheDir: Directory(
      p.join(ref.watch(appCacheDirProvider).path, 'subtitles'),
    ),
  );
  ref.onDispose(sources.close);
  return sources;
});

/// Online subtitle search for the current file (task 2.9).
class SubtitleSearchController extends Notifier<SubtitleSearchState> {
  @override
  SubtitleSearchState build() => const SubtitleSearchState();

  List<String> get _languages => ref
      .read(settingsProvider)
      .subtitleLanguages
      .split(',')
      .map((l) => languageCode2(l.trim()) ?? l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  /// Searches by the file's hash and its parsed title, once per file.
  Future<void> searchForCurrent({bool force = false}) async {
    final source = ref.read(playerServiceProvider).state.source;
    if (source == null) return;
    if (!force && state.source == source && state.status != SearchStatus.idle) {
      return;
    }
    final title = parseMediaTitle(source);
    final episode = RegExp(r'S(\d+)E(\d+)').firstMatch(title.episode ?? '');
    String? hash;
    final file = File(source);
    if (!source.contains('://') && file.existsSync()) {
      try {
        hash = await computeMovieHash(file);
      } on FileSystemException {
        hash = null;
      }
    }
    // The film's IMDb id for the keyless sources (task 9.6).
    final identity = await ref
        .read(mediaIdentifierProvider)
        .identify(source)
        .catchError((Object _) => null);
    await _run(
      source,
      title.title,
      imdbId: identity?.imdbId,
      SubtitleQuery(
        movieHash: hash,
        text: title.title,
        year: episode == null ? title.year : null,
        season: episode == null ? null : int.parse(episode.group(1)!),
        episode: episode == null ? null : int.parse(episode.group(2)!),
        languages: _languages,
      ),
    );
  }

  /// "Find more subtitles": a free-text search.
  Future<void> searchText(String text) async {
    final source = ref.read(playerServiceProvider).state.source;
    if (source == null || text.trim().isEmpty) return;
    final parsed = RegExp(r'^(.*?)\s*[Ss](\d+)\s*[Ee](\d+)\s*$')
        .firstMatch(text.trim());
    await _run(
      source,
      text,
      SubtitleQuery(
        text: parsed?.group(1) ?? text,
        season: parsed == null ? null : int.parse(parsed.group(2)!),
        episode: parsed == null ? null : int.parse(parsed.group(3)!),
        languages: _languages,
      ),
    );
  }

  Future<void> _run(
    String source,
    String text,
    SubtitleQuery query, {
    String? imdbId,
  }) async {
    state = state.copyWith(
      status: SearchStatus.searching,
      source: source,
      queryText: text,
      results: const [],
      message: () => null,
    );
    // OpenSubtitles with the user's key, and the keyless sources, at once.
    OpenSubtitlesException? error;
    var noKey = false;
    final official = ref
        .read(openSubtitlesClientProvider)
        .search(query)
        .catchError((Object e) {
          if (e is MissingApiKey) {
            noKey = true;
          } else if (e is OpenSubtitlesException) {
            error = e;
          }
          return <SubtitleResult>[];
        });
    final free = ref
        .read(freeSubtitleSourcesProvider)
        .search(
          languages: query.languages,
          imdbId: imdbId,
          title: query.text,
          season: query.season,
          episode: query.episode,
        )
        .catchError((Object _) => <SubtitleResult>[]);
    final lists = await Future.wait([official, free]);
    if (ref.read(playerServiceProvider).state.source != source) return;
    final results = rankSubtitles(
      [...lists[0], ...lists[1]],
      videoName: p.basename(source),
      languages: query.languages,
    );
    if (results.isEmpty && error != null) {
      state = state.copyWith(
        status: SearchStatus.failed,
        message: () => error!.message,
      );
      return;
    }
    state = state.copyWith(
      status: SearchStatus.done,
      results: results,
      message: () => results.isEmpty
          ? noKey
                ? 'No subtitles found. Add an OpenSubtitles API key in '
                      'Settings to search more.'
                : 'No subtitles found.'
          : null,
    );
  }

  /// Downloads [result] and loads it as the active subtitle track.
  Future<void> apply(SubtitleResult result) async {
    state = state.copyWith(applyingFileId: () => result.fileId);
    try {
      final file = result.url != null
          ? await ref.read(freeSubtitleSourcesProvider).download(result)
          : await ref.read(openSubtitlesClientProvider).download(result);
      await ref
          .read(playerServiceProvider)
          .addSubtitle(
            // Old encodings become UTF-8 first (task 9.5).
            prepareSubtitleFile(
              file.path,
              cache: ref.read(appCacheDirProvider),
              lang: result.language,
            ),
            title: result.release.isEmpty ? null : result.release,
          );
      state = state.copyWith(
        applyingFileId: () => null,
        appliedFileIds: {...state.appliedFileIds, result.fileId},
      );
    } on OpenSubtitlesException catch (e) {
      state = state.copyWith(
        applyingFileId: () => null,
        message: () => e.message,
      );
    } on FileSystemException catch (e) {
      state = state.copyWith(
        applyingFileId: () => null,
        message: () => "Couldn't save the subtitle: ${e.message}",
      );
    }
  }
}

final subtitleSearchProvider =
    NotifierProvider<SubtitleSearchController, SubtitleSearchState>(
      SubtitleSearchController.new,
    );

/// Harbor's order (task 9.6): found by the file's hash first, then the
/// user's languages in their order, then how well the release name fits
/// the video (episode, group, source, resolution, edition), then not
/// machine-translated, then downloads. Each result gets its fit in %.
List<SubtitleResult> rankSubtitles(
  List<SubtitleResult> results, {
  required String videoName,
  required List<String> languages,
}) {
  final video = ReleaseTags.parse(videoName);
  final scored = [
    for (final r in results)
      (
        r,
        ReleaseAffinity.of(video, r.release.isEmpty ? r.fileName : r.release),
      ),
  ];
  int lang(SubtitleResult r) {
    final i = languages.indexOf(r.language);
    return i < 0 ? languages.length : i;
  }

  scored.sort((a, b) {
    final (ra, ma) = a;
    final (rb, mb) = b;
    if (ra.hashMatch != rb.hashMatch) return ra.hashMatch ? -1 : 1;
    final l = lang(ra).compareTo(lang(rb));
    if (l != 0) return l;
    final c = ma.confidence.index.compareTo(mb.confidence.index);
    if (c != 0) return c;
    final sc = mb.score.compareTo(ma.score);
    if (sc != 0) return sc;
    if (ra.machineTranslated != rb.machineTranslated) {
      return ra.machineTranslated ? 1 : -1;
    }
    return rb.downloadCount.compareTo(ra.downloadCount);
  });
  return [
    for (final (r, m) in scored)
      r.withMatch(
        r.hashMatch ? 100 : m.percent,
        r.hashMatch ? null : m.reasons.firstOrNull,
      ),
  ];
}
