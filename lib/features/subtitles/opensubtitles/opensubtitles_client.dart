import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// One search hit (task 2.9).
@immutable
class SubtitleResult {
  const new({
    required this.fileId,
    required this.language,
    required this.release,
    required this.fileName,
    this.rating = 0,
    this.downloadCount = 0,
    this.hearingImpaired = false,
    this.machineTranslated = false,
    this.hashMatch = false,
  });

  factory fromJson(Map<String, Object?> item) {
    final a = (item['attributes'] as Map?)?.cast<String, Object?>() ?? {};
    final files = (a['files'] as List?) ?? const [];
    final file = files.isEmpty
        ? const <String, Object?>{}
        : (files.first as Map).cast<String, Object?>();
    return SubtitleResult(
      fileId: (file['file_id'] as num?)?.toInt() ?? 0,
      fileName: file['file_name'] as String? ?? '',
      language: a['language'] as String? ?? '',
      release: a['release'] as String? ?? '',
      rating: (a['ratings'] as num?)?.toDouble() ?? 0,
      downloadCount: (a['download_count'] as num?)?.toInt() ?? 0,
      hearingImpaired: a['hearing_impaired'] as bool? ?? false,
      machineTranslated: a['machine_translated'] as bool? ?? false,
      hashMatch: a['moviehash_match'] as bool? ?? false,
    );
  }

  final int fileId;
  final String language;
  final String release;
  final String fileName;
  final double rating;
  final int downloadCount;
  final bool hearingImpaired;
  final bool machineTranslated;

  /// Found by the file's hash, so it should be in sync.
  final bool hashMatch;
}

/// What to search for. Empty fields are left out of the request.
@immutable
class SubtitleQuery {
  const new({
    this.movieHash,
    this.text,
    this.year,
    this.season,
    this.episode,
    this.languages = const ['en'],
  });

  final String? movieHash;
  final String? text;
  final int? year;
  final int? season;
  final int? episode;
  final List<String> languages;

  Map<String, String> toParameters() {
    // OpenSubtitles asks for sorted parameters and lower-case values to
    // improve caching on their side.
    final params = <String, String>{
      if (episode != null) 'episode_number': '$episode',
      'languages': (languages.map((l) => l.toLowerCase()).toList()..sort())
          .join(','),
      'moviehash': ?movieHash,
      if (text != null && text!.trim().isNotEmpty)
        'query': text!.trim().toLowerCase(),
      if (season != null) 'season_number': '$season',
      if (year != null) 'year': '$year',
    };
    return Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String get cacheKey => Uri(queryParameters: toParameters()).query;
}

sealed class OpenSubtitlesException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

class MissingApiKey extends OpenSubtitlesException {
  const new()
    : super('Add an OpenSubtitles API key in Settings to search online.');
}

class RateLimited extends OpenSubtitlesException {
  const new(this.retryAfter)
    : super('OpenSubtitles is busy. Try again shortly.');
  final Duration retryAfter;
}

class QuotaExceeded extends OpenSubtitlesException {
  const new(super.message);
}

class RequestFailed extends OpenSubtitlesException {
  const new(super.message);
}

/// Minimal client for the OpenSubtitles REST API v1.
class OpenSubtitlesClient {
  new({
    required this.apiKey,
    required this.cacheDir,
    http.Client? httpClient,
    this.minInterval = const Duration(milliseconds: 1100),
  }) : _http = httpClient ?? http.Client();

  static final Uri baseUri = Uri.parse('https://api.opensubtitles.com/api/v1/');
  static const userAgent = 'Kyndrel v0.1';

  final String apiKey;

  /// Downloaded files are kept here, named by file id.
  final Directory cacheDir;

  /// Spacing between requests (the API allows a few per second).
  final Duration minInterval;
  final http.Client _http;

  final _searchCache = <String, List<SubtitleResult>>{};
  DateTime? _lastRequest;
  DateTime? _blockedUntil;

  Map<String, String> get _headers => {
    'Api-Key': apiKey,
    'User-Agent': userAgent,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<List<SubtitleResult>> search(SubtitleQuery query) async {
    final cached = _searchCache[query.cacheKey];
    if (cached != null) return cached;
    final response = await _send(
      () => _http.get(
        baseUri
            .resolve('subtitles')
            .replace(queryParameters: query.toParameters()),
        headers: _headers,
      ),
    );
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final results =
        ((body['data'] as List?) ?? const [])
            .map((e) => SubtitleResult.fromJson((e as Map).cast()))
            .where((r) => r.fileId != 0)
            .toList()
          ..sort((a, b) {
            if (a.hashMatch != b.hashMatch) return a.hashMatch ? -1 : 1;
            return b.downloadCount.compareTo(a.downloadCount);
          });
    _searchCache[query.cacheKey] = results;
    return results;
  }

  /// Downloads [result] into [cacheDir] (or reuses an earlier download) and
  /// returns the local file.
  Future<File> download(SubtitleResult result) async {
    final ext = p.extension(result.fileName).isEmpty
        ? '.srt'
        : p.extension(result.fileName);
    final file = File(p.join(cacheDir.path, '${result.fileId}$ext'));
    if (file.existsSync() && file.lengthSync() > 0) return file;

    final response = await _send(
      () => _http.post(
        baseUri.resolve('download'),
        headers: _headers,
        body: jsonEncode({'file_id': result.fileId}),
      ),
    );
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final link = body['link'] as String?;
    if (link == null) throw const RequestFailed('No download link returned.');
    final content = await _http.get(Uri.parse(link));
    if (content.statusCode != 200) {
      throw RequestFailed('Download failed (${content.statusCode}).');
    }
    await cacheDir.create(recursive: true);
    await file.writeAsBytes(content.bodyBytes);
    return file;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    if (apiKey.trim().isEmpty) throw const MissingApiKey();
    final now = clock.now();
    final blocked = _blockedUntil;
    if (blocked != null && now.isBefore(blocked)) {
      throw RateLimited(blocked.difference(now));
    }
    final last = _lastRequest;
    if (last != null) {
      final wait = minInterval - now.difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequest = clock.now();

    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const RequestFailed('OpenSubtitles did not answer in time.');
    } on http.ClientException catch (e) {
      throw RequestFailed('Network error: ${e.message}');
    } on SocketException catch (e) {
      throw RequestFailed('Network error: ${e.message}');
    }

    switch (response.statusCode) {
      case >= 200 && < 300:
        return response;
      case 429:
        final retry = Duration(
          seconds:
              int.tryParse(
                response.headers['retry-after'] ??
                    response.headers['ratelimit-reset'] ??
                    '',
              ) ??
              10,
        );
        _blockedUntil = clock.now().add(retry);
        throw RateLimited(retry);
      case 401 || 403:
        throw const RequestFailed(
          'OpenSubtitles rejected the API key. Check it in Settings.',
        );
      case 406:
        throw QuotaExceeded(
          _message(response) ?? 'Daily download limit reached.',
        );
      default:
        throw RequestFailed(
          _message(response) ?? 'OpenSubtitles error ${response.statusCode}.',
        );
    }
  }

  static String? _message(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map) {
        return (body['message'] ?? body['errors']?.toString())?.toString();
      }
    } on FormatException {
      // Not JSON.
    }
    return null;
  }

  void close() => _http.close();
}
