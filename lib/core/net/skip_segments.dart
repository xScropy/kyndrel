import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// What a skip segment covers (task 9.8).
enum SkipKind { intro, recap, outro }

/// One stretch to skip, from an online database or the file's chapters.
@immutable
class SkipSegment {
  const new(this.kind, this.start, this.end, this.source);

  final SkipKind kind;
  final Duration start;
  final Duration end;

  /// `aniskip`, `theintrodb`, `skipdb`, `introdb`, `chapters`, `local`.
  final String source;

  @override
  bool operator ==(Object other) =>
      other is SkipSegment &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.source == source;

  @override
  int get hashCode => Object.hash(kind, start, end, source);

  @override
  String toString() => 'SkipSegment($kind, $start–$end, $source)';
}

/// Harbor's skip-segment sources (task 9.8): AniSkip for anime (by
/// MyAnimeList id), then TheIntroDB, SkipDB and IntroDB (by IMDb id). The
/// first source wins where segments overlap. None needs a key.
class SkipSegmentsClient {
  new({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final _cache = <String, Future<List<SkipSegment>>>{};

  /// A source that failed is left alone this long.
  static const cooldown = Duration(minutes: 10);
  static const timeout = Duration(seconds: 8);
  final _coolingUntil = <String, DateTime>{};

  /// Longest segment believed (Harbor: 6 min).
  static const maxSegment = Duration(minutes: 6);

  /// Credits start in the second half.
  static const minOutroFraction = 0.5;

  Future<List<SkipSegment>> fetch({
    required Duration duration,
    String? imdbId,
    int? season,
    int? episode,
    int? malId,
  }) {
    final key = '$imdbId|$season|$episode|$malId|${duration.inSeconds}';
    return _cache.putIfAbsent(key, () async {
      final lists = await Future.wait([
        if (malId != null && episode != null)
          _aniSkip(malId, episode, duration),
        if (imdbId != null) ...[
          _theIntroDb(imdbId, season, episode, duration),
          _skipDb(imdbId, season, episode, duration),
          if (season != null && episode != null)
            _introDb(imdbId, season, episode),
        ],
      ]);
      return merge(lists, duration);
    });
  }

  /// Joins [lists] in priority order: a segment overlapping one already
  /// kept is dropped; implausible ones (too long, credits too early) go.
  static List<SkipSegment> merge(
    List<List<SkipSegment>> lists,
    Duration duration,
  ) {
    final out = <SkipSegment>[];
    for (final list in lists) {
      for (final s in list) {
        if (s.end <= s.start || s.end - s.start > maxSegment) continue;
        if (s.kind == SkipKind.outro &&
            duration > Duration.zero &&
            s.start < duration * minOutroFraction) {
          continue;
        }
        final overlaps = out.any((o) => s.start < o.end && s.end > o.start);
        if (!overlaps) out.add(s);
      }
    }
    return out..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<Object?> _get(String source, Uri url) async {
    final until = _coolingUntil[source];
    if (until != null && DateTime.now().isBefore(until)) return null;
    try {
      final r = await _http.get(url).timeout(timeout);
      if (r.statusCode == 404) return null;
      if (r.statusCode != 200) {
        _coolingUntil[source] = DateTime.now().add(cooldown);
        return null;
      }
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on Object {
      _coolingUntil[source] = DateTime.now().add(cooldown);
      return null;
    }
  }

  static Duration _ms(Object? v) =>
      Duration(milliseconds: (v as num?)?.round() ?? -1);

  Future<List<SkipSegment>> _aniSkip(
    int malId,
    int episode,
    Duration duration,
  ) async {
    final types = ['op', 'ed', 'mixed-op', 'mixed-ed', 'recap'];
    final url = Uri.parse(
      'https://api.aniskip.com/v2/skip-times/$malId/$episode'
      '?${types.map((t) => 'types=$t').join('&')}'
      '&episodeLength=${duration.inSeconds}',
    );
    final json = await _get('aniskip', url);
    if (json is! Map || json['found'] != true) return const [];
    return [
      for (final r
          in (json['results'] as List? ?? const [])
              .whereType<Map<dynamic, dynamic>>())
        if (r['interval'] case {
          'startTime': final num start,
          'endTime': final num end,
        })
          SkipSegment(
            switch (r['skipType']) {
              'ed' || 'mixed-ed' => SkipKind.outro,
              'recap' => SkipKind.recap,
              _ => SkipKind.intro,
            },
            Duration(milliseconds: (start * 1000).round()),
            Duration(milliseconds: (end * 1000).round()),
            'aniskip',
          ),
    ];
  }

  Future<List<SkipSegment>> _theIntroDb(
    String imdbId,
    int? season,
    int? episode,
    Duration duration,
  ) async {
    final url = Uri.https('api.theintrodb.org', '/v4/media', {
      'imdb_id': imdbId,
      if (season != null && episode != null) ...{
        'season': '$season',
        'episode': '$episode',
      },
      if (duration > Duration.zero) 'duration_ms': '${duration.inMilliseconds}',
    });
    final json = await _get('theintrodb', url);
    if (json is! Map) return const [];
    final out = <SkipSegment>[];
    void collect(String key, SkipKind kind) {
      for (final s
          in (json[key] as List? ?? const [])
              .whereType<Map<dynamic, dynamic>>()) {
        final start = s['start_ms'] == null
            ? Duration.zero
            : _ms(s['start_ms']);
        final end = s['end_ms'] == null ? duration : _ms(s['end_ms']);
        out.add(SkipSegment(kind, start, end, 'theintrodb'));
      }
    }

    collect('intro', SkipKind.intro);
    collect('recap', SkipKind.recap);
    collect('credits', SkipKind.outro);
    collect('preview', SkipKind.outro);
    return out;
  }

  Future<List<SkipSegment>> _skipDb(
    String imdbId,
    int? season,
    int? episode,
    Duration duration,
  ) async {
    final url = Uri.https('api.skipdb.tv', '/api/segments', {
      'imdb_id': imdbId,
      if (season != null && episode != null) ...{
        'season': '$season',
        'episode': '$episode',
      },
      if (duration > Duration.zero) 'duration': '${duration.inSeconds}',
    });
    final json = await _get('skipdb', url);
    final segments = json is Map ? json['segments'] : null;
    if (segments is! Map) return const [];
    return [
      for (final (key, kind) in const [
        ('intro', SkipKind.intro),
        ('recap', SkipKind.recap),
        ('outro', SkipKind.outro),
        ('preview', SkipKind.outro),
      ])
        if (segments[key] case final Map<dynamic, dynamic> s
            when s['match'] != 'out-of-range' &&
                ((s['confidence'] as num?) ?? 1) >= 0.35)
          SkipSegment(kind, _ms(s['start_ms']), _ms(s['end_ms']), 'skipdb'),
    ];
  }

  Future<List<SkipSegment>> _introDb(
    String imdbId,
    int season,
    int episode,
  ) async {
    final url = Uri.https('api.introdb.app', '/segments', {
      'imdb_id': imdbId,
      'season': '$season',
      'episode': '$episode',
    });
    final json = await _get('introdb', url);
    if (json is! Map) return const [];
    return [
      for (final (key, kind) in const [
        ('intro', SkipKind.intro),
        ('recap', SkipKind.recap),
        ('outro', SkipKind.outro),
      ])
        if (json[key] case final Map<dynamic, dynamic> s)
          SkipSegment(kind, _ms(s['start_ms']), _ms(s['end_ms']), 'introdb'),
    ];
  }

  void close() => _http.close();
}

final skipSegmentsClientProvider = Provider<SkipSegmentsClient>((ref) {
  final c = SkipSegmentsClient();
  ref.onDispose(c.close);
  return c;
});
