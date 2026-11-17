import 'package:path/path.dart' as p;

/// Title details guessed from a file name or URL (task 1.3).
typedef MediaTitle = ({String title, int? year, String? episode});

final _episode = RegExp(
  r'\b[Ss](\d{1,2})[ ._-]?[Ee](\d{1,3})\b|\b(\d{1,2})x(\d{2,3})\b',
);
final _year = RegExp(r'[\(\[]?\b(19[2-9]\d|20[0-9]\d)\b[\)\]]?');

/// Release tags that end a title: `1080p`, `BluRay`, `x264`...
final _tags = RegExp(
  r'\b(2160p|1080p|720p|576p|480p|4k|uhd|hdr10?\+?|dv|bluray|blu-ray|brrip|'
  r'bdrip|web-?dl|webrip|web|hdtv|dvdrip|remux|x264|x265|h\.?264|h\.?265|hevc|'
  r'av1|aac|ac3|dts|ddp?5\.1|atmos|proper|repack|extended|unrated|'
  r'imax|10bit|multi)\b',
  caseSensitive: false,
);

/// `The.Matrix.1999.1080p.BluRay.mkv` → `The Matrix`, 1999.
/// `Show.Name.S01E02.Title.mkv` → `Show Name`, episode `S01E02`.
MediaTitle parseMediaTitle(String source) {
  var name = source;
  final uri = Uri.tryParse(source);
  if (uri != null && uri.hasScheme && uri.scheme.length > 1) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    name = segments.isEmpty ? uri.host : Uri.decodeComponent(segments.last);
  } else {
    name = p.basename(source.replaceAll(r'\', '/'));
  }
  name = p.basenameWithoutExtension(name);
  if (name.isEmpty) return (title: source, year: null, episode: null);

  // Dots and underscores as separators, unless the name has spaces already.
  var text = name.contains(' ') ? name : name.replaceAll(RegExp('[._]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  String? episode;
  var cut = text.length;
  final ep = _episode.firstMatch(text);
  if (ep != null) {
    final season = int.parse(ep.group(1) ?? ep.group(3)!);
    final number = int.parse(ep.group(2) ?? ep.group(4)!);
    episode =
        'S${season.toString().padLeft(2, '0')}'
        'E${number.toString().padLeft(2, '0')}';
    cut = ep.start;
  }

  int? year;
  // The last year-like number before the tags is the release year; a title
  // can itself contain a year ("2001 A Space Odyssey 1968").
  final yearMatches = _year
      .allMatches(text.substring(0, cut))
      .where((m) => m.start > 0)
      .toList();
  if (yearMatches.isNotEmpty) {
    final m = yearMatches.last;
    year = int.parse(m.group(1)!);
    cut = m.start;
  }

  final tag = _tags.firstMatch(text.substring(0, cut));
  if (tag != null && tag.start > 0) cut = tag.start;

  var title = text.substring(0, cut).trim();
  title = title.replaceAll(RegExp(r'[\s\-\(\[]+$'), '').trim();
  if (title.isEmpty) title = text;
  return (title: title, year: year, episode: episode);
}

/// Quality badge from the video size: `480P`, `720P`, `1080P`, `1440P`, `4K`.
///
/// Uses the width too, so a 1920×800 scope film still reads `1080P`.
String? qualityLabel(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  final effective = height > width * 9 / 16 ? height : (width * 9 / 16).round();
  if (effective >= 2000) return '4K';
  if (effective >= 1400) return '1440P';
  if (effective >= 1000) return '1080P';
  if (effective >= 700) return '720P';
  if (effective >= 560) return '576P';
  if (effective >= 460) return '480P';
  if (effective >= 340) return '360P';
  return '${effective}P';
}
