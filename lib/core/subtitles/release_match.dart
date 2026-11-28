import 'package:flutter/foundation.dart';

/// How a subtitle's release name fits the video's (task 9.6, Harbor's
/// `release-match.ts`): the same episode, release group, source (BluRay,
/// WEB-DL...), resolution, HDR and edition mean the timing likely fits.
enum SourceClass { remux, bluray, webdl, webrip, hdtv, dvd, cam }

enum MatchConfidence { high, medium, low, incompatible }

/// What a release name says.
@immutable
class ReleaseTags {
  const new({
    this.group,
    this.source,
    this.resolution,
    this.hdr = const [],
    this.edition = const [],
    this.season,
    this.episode,
    this.episodeEnd,
    this.proper = false,
    this.repack = false,
  });

  factory parse(String? text) {
    final s = text ?? '';
    final res = RegExp(
      r'\b(2160p|1080p|720p|576p|480p)\b',
      caseSensitive: false,
    ).firstMatch(s);
    final fourK =
        res == null &&
        RegExp(r'\b(4k|uhd)\b', caseSensitive: false).hasMatch(s);
    final ep = _episodeRange(s);
    return ReleaseTags(
      group: detectGroup(s),
      source: detectSource(s),
      resolution: res != null
          ? res[1]!.toLowerCase()
          : fourK
          ? '2160p'
          : null,
      hdr: [
        for (final (k, rx) in _hdr)
          if (rx.hasMatch(s)) k,
      ],
      edition: [
        for (final (k, rx) in _editions)
          if (rx.hasMatch(s)) k,
      ],
      season: ep?.$1,
      episode: ep?.$2,
      episodeEnd: ep?.$3,
      proper: RegExp(r'\bproper\b', caseSensitive: false).hasMatch(s),
      repack: RegExp(r'\brepack\b', caseSensitive: false).hasMatch(s),
    );
  }

  final String? group;
  final SourceClass? source;
  final String? resolution;
  final List<String> hdr;
  final List<String> edition;
  final int? season;
  final int? episode;
  final int? episodeEnd;
  final bool proper;
  final bool repack;

  static const _knownGroups = [
    'EVO', 'RARBG', 'YTS', 'YIFY', 'FGT', 'PSA', 'TBS', 'GALAXYRG', //
    'GALAXYTV', 'MEGUSTA', 'ION10', 'EZTV', 'NTB', 'FLUX', 'TEPES', 'KOGI',
    'SMURF', 'RZEROX', 'D3G', 'TGX', 'SPARKS', 'AMIABLE', 'GECKOS',
    'DRONES', 'CMRG', 'PAHE', 'QXR', 'TIGOLE', 'JOY', 'FRAMESTOR',
    'HDMANIACS', 'WIKI', 'DON', 'EBP', 'BLURANIUM', '3L', 'BMF', 'TRUFFLE',
    'SICFOI', 'PMTP', 'KINGS', 'CAKES', 'SUCCESSFULCRAB', 'ELITE', 'TOMMY',
    'MZABI', 'PLAYWEB', 'XEBEC', 'SEV', 'NOSIVID', 'TVSMASH', 'MINX',
    'EDITH', 'TEAMHD',
  ];

  static final _sources = <(SourceClass, RegExp)>[
    (SourceClass.remux, RegExp(r'\bremux\b', caseSensitive: false)),
    (
      SourceClass.bluray,
      RegExp(
        r'\b(blu-?ray|bd-?rip|br-?rip|bd(?:25|50)|bdmv)\b',
        caseSensitive: false,
      ),
    ),
    (SourceClass.webrip, RegExp(r'\bweb-?rip\b', caseSensitive: false)),
    (
      SourceClass.webdl,
      RegExp(
        r'\b(web-?dl|webdl|web|amzn|dsnp|hmax|atvp|nflx|pcok|itunes)\b',
        caseSensitive: false,
      ),
    ),
    (SourceClass.hdtv, RegExp(r'\b(hdtv|pdtv|dsr)\b', caseSensitive: false)),
    (
      SourceClass.dvd,
      RegExp(r'\b(dvd-?rip|dvd-?r|dvd5|dvd9)\b', caseSensitive: false),
    ),
    (
      SourceClass.cam,
      RegExp(
        r'\b(hd-?cam|hd-?ts|telesync|telecine|screener|camrip)\b',
        caseSensitive: false,
      ),
    ),
  ];

  static final _editions = <(String, RegExp)>[
    ('extended', RegExp(r'\bextended\b', caseSensitive: false)),
    (
      'directors',
      RegExp(r"\b(director'?s?[. _-]?cut|dc)\b", caseSensitive: false),
    ),
    ('uncut', RegExp(r'\buncut\b', caseSensitive: false)),
    ('unrated', RegExp(r'\bunrated\b', caseSensitive: false)),
    ('theatrical', RegExp(r'\btheatrical\b', caseSensitive: false)),
    ('imax', RegExp(r'\bimax\b', caseSensitive: false)),
    ('criterion', RegExp(r'\bcriterion\b', caseSensitive: false)),
    ('remastered', RegExp(r'\bremaster(?:ed)?\b', caseSensitive: false)),
    ('finalcut', RegExp(r'\bfinal[. _-]?cut\b', caseSensitive: false)),
  ];

  static final _hdr = <(String, RegExp)>[
    ('dv', RegExp(r'\b(dv|dovi|dolby[. _-]?vision)\b', caseSensitive: false)),
    ('hdr10plus', RegExp(r'(hdr10\+|\bhdr10plus\b)', caseSensitive: false)),
    ('hdr', RegExp(r'\bhdr(?!10\+)\b', caseSensitive: false)),
    ('hlg', RegExp(r'\bhlg\b', caseSensitive: false)),
    ('sdr', RegExp(r'\bsdr\b', caseSensitive: false)),
  ];

  static final _notGroup = RegExp(
    '^(MKV|MP4|AVI|SRT|ASS|SSA|VTT|1080P|720P|2160P|X264|X265|H264|H265|'
    r'HEVC|AAC|DTS|DDP5|WEB)$',
  );

  static String? detectGroup(String text) {
    if (text.isEmpty) return null;
    final upper = text.toUpperCase();
    for (final g in _knownGroups) {
      if (RegExp('(^|[^A-Z0-9])$g([^A-Z0-9]|\$)').hasMatch(upper)) return g;
    }
    final trailing = RegExp(r'[-.]([A-Za-z0-9]{3,20})(?:\.[a-z0-9]{2,4})?\s*$')
        .firstMatch(text);
    if (trailing != null) {
      final c = trailing[1]!.toUpperCase();
      if (!_notGroup.hasMatch(c)) return c;
    }
    return null;
  }

  static SourceClass? detectSource(String text) {
    for (final (c, rx) in _sources) {
      if (rx.hasMatch(text)) return c;
    }
    return null;
  }

  static (int, int, int)? _episodeRange(String text) {
    final m =
        RegExp(
          r'(?:^|[^a-z0-9])s(\d{1,2})[ ._-]*e(\d{1,3})'
          r'(?:(?:[ ._-]*-?[ ._-]*e?)(\d{1,3}))?(?:[^a-z0-9]|$)',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'(?:^|[^a-z0-9])(\d{1,2})x(\d{1,3})'
          r'(?:[ ._-]*-?[ ._-]*(\d{1,3}))?(?:[^a-z0-9]|$)',
          caseSensitive: false,
        ).firstMatch(text);
    if (m == null) return null;
    final season = int.parse(m[1]!);
    final episode = int.parse(m[2]!);
    final end = m[3] == null ? episode : int.parse(m[3]!);
    return (season, episode, end < episode ? episode : end);
  }
}

/// How well a subtitle fits: a score, Harbor's confidence band and why.
@immutable
class ReleaseAffinity {
  const new(this.score, this.confidence, this.reasons);

  /// [video] is the playing file's tags; [subtitle] the subtitle's release
  /// or file name.
  factory of(ReleaseTags video, String subtitle) {
    final sub = ReleaseTags.parse(subtitle);
    final reasons = <String>[];
    var score = 0;
    var incompatible = false;
    var episodeMatch = false;
    var editionMatch = false;
    final affinity = sourceAffinity(video.source, sub.source);
    final rank = video.source == null || sub.source == null
        ? 1
        : affinity >= 1
        ? 3
        : affinity >= 0.75
        ? 2
        : 1;

    if (video.season != null &&
        video.episode != null &&
        sub.season != null &&
        sub.episode != null) {
      final end = sub.episodeEnd ?? sub.episode!;
      if (video.season == sub.season &&
          video.episode! >= sub.episode! &&
          video.episode! <= end) {
        score += 80;
        episodeMatch = true;
        reasons.add('S${video.season}E${video.episode} matches');
      } else {
        score -= 300;
        incompatible = true;
        reasons.add('for S${sub.season}E${sub.episode}');
      }
    }
    final groupMatch =
        video.group != null && sub.group != null && video.group == sub.group;
    if (groupMatch) {
      score += 120;
      reasons.add('same release group ${sub.group}');
    }
    if (video.source != null && sub.source != null) {
      if (affinity >= 1) {
        score += 45;
        reasons.add('${sub.source!.name} like the video');
      } else if (affinity >= 0.75) {
        score += (45 * affinity).round();
        reasons.add('${sub.source!.name}, close to ${video.source!.name}');
      } else {
        score -= 30;
        incompatible = true;
        reasons.add('${sub.source!.name} timing differs');
      }
    } else if (video.source != null) {
      score += 2;
    }
    if (video.resolution != null && sub.resolution != null) {
      if (video.resolution == sub.resolution) {
        score += 8;
        reasons.add(sub.resolution!);
      } else {
        score -= 4;
      }
    }
    final sharedHdr = sub.hdr.where(video.hdr.contains).toList();
    if (sharedHdr.isNotEmpty) {
      score += 10;
      reasons.add(sharedHdr.join(' '));
    }
    final videoEd = video.edition.where((e) => e != 'remastered').toList();
    final subEd = sub.edition.where((e) => e != 'remastered').toList();
    if (videoEd.isNotEmpty && subEd.isNotEmpty) {
      final shared = subEd.where(videoEd.contains).toList();
      if (shared.isNotEmpty) {
        score += 25;
        editionMatch = true;
        reasons.add('${shared.first} edition');
      } else {
        score -= 25;
        incompatible = true;
        reasons.add('another edition (${subEd.first})');
      }
    } else if (videoEd.isNotEmpty) {
      score -= 10;
    } else if (subEd.isNotEmpty) {
      score -= 15;
      reasons.add('${subEd.first} cut');
    }
    if (video.proper && sub.proper) {
      score += 6;
    } else if (video.proper != sub.proper) {
      score -= 3;
    }
    if (video.repack && sub.repack) score += 4;

    final confidence = incompatible
        ? MatchConfidence.incompatible
        : groupMatch || (rank == 3 && (episodeMatch || editionMatch))
        ? MatchConfidence.high
        : rank >= 2
        ? MatchConfidence.medium
        : MatchConfidence.low;
    return ReleaseAffinity(score, confidence, reasons);
  }

  final int score;
  final MatchConfidence confidence;
  final List<String> reasons;

  /// 0–100, the bands never overlapping (Harbor's compatibility percent).
  int get percent {
    final e = score < 0 ? 0 : score;
    int band(int lo, int hi, int over) =>
        (lo + (e.clamp(0, over) / over) * (hi - lo)).round();
    return switch (confidence) {
      MatchConfidence.high => band(75, 99, 240),
      MatchConfidence.medium => band(50, 74, 120),
      MatchConfidence.low => band(20, 49, 100),
      MatchConfidence.incompatible => band(0, 19, 100),
    };
  }

  static const _compat = <SourceClass, Map<SourceClass, double>>{
    SourceClass.remux: {SourceClass.bluray: 0.85, SourceClass.webdl: 0.25},
    SourceClass.bluray: {SourceClass.remux: 0.85, SourceClass.webdl: 0.25},
    SourceClass.webdl: {
      SourceClass.webrip: 0.75,
      SourceClass.bluray: 0.25,
      SourceClass.remux: 0.25,
    },
    SourceClass.webrip: {SourceClass.webdl: 0.75},
  };

  static double sourceAffinity(SourceClass? want, SourceClass? got) {
    if (want == null || got == null) return 0;
    if (want == got) return 1;
    return _compat[want]?[got] ?? 0;
  }
}
