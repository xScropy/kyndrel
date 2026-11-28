import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/subtitles/subtitle_prepare.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/core/utils/media_title.dart';
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
    await _run(
      source,
      title.title,
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

  Future<void> _run(String source, String text, SubtitleQuery query) async {
    state = state.copyWith(
      status: SearchStatus.searching,
      source: source,
      queryText: text,
      results: const [],
      message: () => null,
    );
    try {
      final results = await ref.read(openSubtitlesClientProvider).search(query);
      if (ref.read(playerServiceProvider).state.source != source) return;
      state = state.copyWith(
        status: SearchStatus.done,
        results: results,
        message: () => results.isEmpty ? 'No subtitles found.' : null,
      );
    } on OpenSubtitlesException catch (e) {
      state = state.copyWith(
        status: SearchStatus.failed,
        message: () => e.message,
      );
    }
  }

  /// Downloads [result] and loads it as the active subtitle track.
  Future<void> apply(SubtitleResult result) async {
    state = state.copyWith(applyingFileId: () => result.fileId);
    try {
      final file = await ref.read(openSubtitlesClientProvider).download(result);
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
