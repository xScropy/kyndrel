import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/opensubtitles_client.dart';
import 'package:path/path.dart' as p;

/// Subtitle sources that need no account or key (task 9.6, as in Harbor):
/// the OpenSubtitles addon Stremio runs (by IMDb id) and Wyzie (by IMDb id
/// or title). Failures give no results rather than errors.
class FreeSubtitleSources {
  new({required this.cacheDir, http.Client? client})
    : _http = client ?? http.Client();

  final Directory cacheDir;
  final http.Client _http;
  final _cache = <String, Future<List<SubtitleResult>>>{};

  static const openSubtitlesAddon = 'https://opensubtitles-v3.strem.io';
  static const wyzie = 'https://sub.wyzie.io/search';
  static const timeout = Duration(seconds: 12);

  Future<List<SubtitleResult>> search({
    required List<String> languages,
    String? imdbId,
    String? title,
    int? season,
    int? episode,
  }) {
    final key = '$imdbId|$title|$season|$episode|${languages.join(',')}';
    return _cache.putIfAbsent(key, () async {
      final lists = await Future.wait([
        if (imdbId != null) _addon(imdbId, season, episode, languages),
        if (imdbId != null || (title?.trim().isNotEmpty ?? false))
          _wyzie(imdbId, title, season, episode, languages),
      ]);
      final seen = <String>{};
      return [
        for (final list in lists)
          for (final r in list)
            if (seen.add(r.url ?? '${r.fileId}')) r,
      ];
    });
  }

  static bool _wanted(String lang, List<String> languages) =>
      languages.isEmpty || languages.contains(lang);

  static int _idOf(String url) => url.hashCode & 0x3fffffff;

  Future<Object?> _json(Uri url) async {
    try {
      final r = await _http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on Object {
      return null;
    }
  }

  Future<List<SubtitleResult>> _addon(
    String imdbId,
    int? season,
    int? episode,
    List<String> languages,
  ) async {
    final series = season != null && episode != null;
    final id = series ? '$imdbId:$season:$episode' : imdbId;
    final json = await _json(
      Uri.parse(
        '$openSubtitlesAddon/subtitles/${series ? 'series' : 'movie'}/$id.json',
      ),
    );
    final list = json is Map ? json['subtitles'] : null;
    if (list is! List) return const [];
    final perLanguage = <String, int>{};
    final out = <SubtitleResult>[];
    for (final s in list.whereType<Map<dynamic, dynamic>>()) {
      final url = s['url'];
      if (url is! String || url.isEmpty) continue;
      final lang = languageCode2('${s['lang'] ?? ''}') ?? '${s['lang']}';
      if (!_wanted(lang, languages)) continue;
      final n = perLanguage[lang] = (perLanguage[lang] ?? 0) + 1;
      out.add(
        SubtitleResult(
          fileId: _idOf(url),
          language: lang,
          release: 'OpenSubtitles #$n',
          fileName: '${s['id'] ?? ''}.srt',
          provider: 'OpenSubtitles (free)',
          url: url,
        ),
      );
    }
    return out;
  }

  Future<List<SubtitleResult>> _wyzie(
    String? imdbId,
    String? title,
    int? season,
    int? episode,
    List<String> languages,
  ) async {
    final json = await _json(
      Uri.parse(wyzie).replace(
        queryParameters: {
          if (imdbId != null) 'id': imdbId else 'query': title!.trim(),
          if (season != null) 'season': '$season',
          if (episode != null) 'episode': '$episode',
          'source': 'all',
          if (languages.isNotEmpty) 'language': languages.join(','),
        },
      ),
    );
    if (json is! List) return const [];
    final out = <SubtitleResult>[];
    for (final s in json.whereType<Map<dynamic, dynamic>>()) {
      final url = s['url'];
      if (url is! String || url.isEmpty) continue;
      final lang =
          languageCode2('${s['language'] ?? ''}') ??
          languageCode2('${s['display'] ?? ''}') ??
          '${s['language'] ?? ''}';
      if (!_wanted(lang, languages)) continue;
      final format = '${s['format'] ?? 'srt'}'.toLowerCase();
      out.add(
        SubtitleResult(
          fileId: _idOf(url),
          language: lang,
          release: '${s['release'] ?? s['display'] ?? ''}',
          fileName: 'wyzie.$format',
          downloadCount: (s['downloads'] as num?)?.toInt() ?? 0,
          hearingImpaired: s['isHearingImpaired'] == true || s['hi'] == true,
          provider: 'Wyzie',
          url: url,
        ),
      );
    }
    return out;
  }

  /// Downloads [result] (a plain, gzipped or zipped subtitle) into the
  /// cache, or reuses an earlier download.
  Future<File> download(SubtitleResult result) async {
    final url = result.url;
    if (url == null) throw const RequestFailed('No download link.');
    var ext = p.extension(result.fileName).toLowerCase();
    if (ext.isEmpty || ext == '.zip' || ext == '.gz') ext = '.srt';
    final file = File(p.join(cacheDir.path, 'free', '${result.fileId}$ext'));
    if (file.existsSync() && file.lengthSync() > 0) return file;
    final http.Response r;
    try {
      r = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    } on Object catch (e) {
      throw RequestFailed('Download failed: $e');
    }
    if (r.statusCode != 200) {
      throw RequestFailed('Download failed (${r.statusCode}).');
    }
    var bytes = r.bodyBytes as List<int>;
    if (bytes.length > 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      bytes = gzip.decode(bytes);
    } else if (bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sub = archive.files.where((f) {
        final e = p.extension(f.name).toLowerCase();
        return f.isFile &&
            const ['.srt', '.ass', '.ssa', '.vtt', '.sub'].contains(e);
      }).firstOrNull;
      if (sub == null) throw const RequestFailed('No subtitle in the archive.');
      bytes = sub.content;
      ext = p.extension(sub.name).toLowerCase();
    }
    final out = File(p.join(cacheDir.path, 'free', '${result.fileId}$ext'));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes);
    return out;
  }

  void close() => _http.close();
}
