import 'package:flutter/foundation.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';
import 'package:path/path.dart' as p;

/// Show, season and episode parsed from a file name (task 3.2).
@immutable
class EpisodeInfo {
  const new({
    required this.show,
    required this.season,
    required this.episode,
    this.lastEpisode,
  });

  /// Normalised show name ("show name") used to group files.
  final String show;
  final int season;
  final int episode;

  /// For double episodes such as `S01E01E02` or `S01E01-02`.
  final int? lastEpisode;

  String get code {
    String two(int n) => n.toString().padLeft(2, '0');
    final last = lastEpisode == null ? '' : '-E${two(lastEpisode!)}';
    return 'S${two(season)}E${two(episode)}$last';
  }

  int compareTo(EpisodeInfo o) => season != o.season
      ? season.compareTo(o.season)
      : episode.compareTo(o.episode);

  @override
  bool operator ==(Object other) =>
      other is EpisodeInfo &&
      other.show == show &&
      other.season == season &&
      other.episode == episode &&
      other.lastEpisode == lastEpisode;

  @override
  int get hashCode => Object.hash(show, season, episode, lastEpisode);

  @override
  String toString() => '$show $code';
}

final _patterns = <RegExp>[
  // S01E02, S1E2, S01.E02, S01E01E02, S01E01-E02, S01E01-02
  RegExp(
    r'^(.*?)[\s._\-\[(]*[Ss](\d{1,2})[\s._-]?[Ee](\d{1,4})(?:[-]?[Ee]?(\d{1,4}))?(?!\d)',
  ),
  // 1x02
  RegExp(r'^(.*?)[\s._\-\[(]*(\d{1,2})x(\d{2,4})(?!\d)'),
  // Season 1 Episode 2
  RegExp(
    r'^(.*?)[\s._\-]*season[\s._]*(\d{1,2})[\s._\-]*episode[\s._]*(\d{1,4})',
    caseSensitive: false,
  ),
];

/// Anime-style "Show - 05" (season 1). Needs a separator and no year.
final _absolute = RegExp(r'^(.*?)\s+-\s+(\d{1,4})(?:v\d)?(?:\s|$|\[|\()');

/// Parses [path] (file name or URL) as an episode; null if it isn't one.
EpisodeInfo? parseEpisode(String path) {
  var name = p.basenameWithoutExtension(path.replaceAll(r'\', '/'));
  // Leading release-group tags: "[Group] Show - 01".
  name = name.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
  for (final re in _patterns) {
    final m = re.firstMatch(name);
    if (m != null) {
      final last = m.groupCount >= 4 ? m.group(4) : null;
      return EpisodeInfo(
        show: _normalise(m.group(1)!),
        season: int.parse(m.group(2)!),
        episode: int.parse(m.group(3)!),
        lastEpisode: last == null ? null : int.parse(last),
      );
    }
  }
  final a = _absolute.firstMatch(name);
  if (a != null) {
    final n = int.parse(a.group(2)!);
    // "Movie - 2019" is a year, not an episode.
    if (n >= 1900 && n <= 2099) return null;
    return EpisodeInfo(show: _normalise(a.group(1)!), season: 1, episode: n);
  }
  return null;
}

String _normalise(String raw) => raw
    .replaceAll(RegExp('[._]'), ' ')
    .replaceAll(RegExp(r'\(\d{4}\)|\b(19|20)\d{2}\b'), '')
    .replaceAll(RegExp(r'[\[\]()\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

/// Sorts paths by episode order when they parse as episodes, else
/// naturally by file name. Episodes come first, grouped by show.
List<String> sortEpisodes(Iterable<String> paths) {
  final list = paths.toList();
  int cmp(String a, String b) {
    final ea = parseEpisode(a);
    final eb = parseEpisode(b);
    if (ea != null && eb != null) {
      final s = ea.show.compareTo(eb.show);
      return s != 0 ? s : ea.compareTo(eb);
    }
    if (ea != null) return -1;
    if (eb != null) return 1;
    return compareNatural(p.basename(a), p.basename(b));
  }

  return list..sort(cmp);
}

/// The episodes of [current]'s show among [siblings], in order, starting
/// with [current]. Empty if [current] isn't an episode.
List<String> episodesFrom(String current, Iterable<String> siblings) {
  final info = parseEpisode(current);
  if (info == null) return const [];
  final same = siblings.where((s) => parseEpisode(s)?.show == info.show);
  final ordered = sortEpisodes({...same, current});
  return ordered.sublist(ordered.indexOf(current));
}
