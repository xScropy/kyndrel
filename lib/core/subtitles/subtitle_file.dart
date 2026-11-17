import 'package:flutter/foundation.dart';

/// One timed subtitle line.
@immutable
class Cue {
  const new(this.start, this.end, this.text);

  final Duration start;
  final Duration end;

  /// Plain text; line breaks as `\n`.
  final String text;

  Cue withText(String t) => Cue(start, end, t);

  @override
  bool operator ==(Object other) =>
      other is Cue &&
      other.start == start &&
      other.end == end &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'Cue($start, $end, $text)';
}

/// Reads SRT, WebVTT and ASS/SSA dialogue (task 4.2). Styling tags are
/// dropped; line breaks are kept.
List<Cue> parseSubtitles(String content, {String? extension}) {
  final text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final ext = extension?.toLowerCase().replaceAll('.', '');
  if (ext == 'ass' || ext == 'ssa' || text.contains('[Events]')) {
    return _parseAss(text);
  }
  return _parseSrtOrVtt(text);
}

final _time = RegExp(
  r'(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})',
);

Duration _t(String? h, String m, String s, String ms) => Duration(
  hours: int.parse(h ?? '0'),
  minutes: int.parse(m),
  seconds: int.parse(s),
  milliseconds: int.parse(ms.padRight(3, '0')),
);

List<Cue> _parseSrtOrVtt(String text) {
  final cues = <Cue>[];
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    final i = lines.indexWhere(_time.hasMatch);
    if (i < 0) continue;
    final m = _time.firstMatch(lines[i])!;
    final body = lines
        .skip(i + 1)
        .join('\n')
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
        .trim();
    if (body.isEmpty) continue;
    cues.add(
      Cue(
        _t(m.group(1), m.group(2)!, m.group(3)!, m.group(4)!),
        _t(m.group(5), m.group(6)!, m.group(7)!, m.group(8)!),
        body,
      ),
    );
  }
  return cues;
}

List<Cue> _parseAss(String text) {
  final cues = <Cue>[];
  List<String>? format;
  final assTime = RegExp(r'^(\d+):(\d{2}):(\d{2})\.(\d{1,3})$');
  Duration? at(String s) {
    final m = assTime.firstMatch(s.trim());
    if (m == null) return null;
    return _t(
      m.group(1),
      m.group(2)!,
      m.group(3)!,
      m.group(4)!.padRight(3, '0'),
    );
  }

  for (final line in text.split('\n')) {
    if (line.startsWith('Format:') && format == null && line.contains('Text')) {
      format = line.substring(7).split(',').map((s) => s.trim()).toList();
    } else if (line.startsWith('Dialogue:') && format != null) {
      final parts = line.substring(9).split(',');
      if (parts.length < format.length) continue;
      final value = <String, String>{};
      for (var i = 0; i < format.length - 1; i++) {
        value[format[i]] = parts[i].trim();
      }
      value['Text'] = parts.sublist(format.length - 1).join(',');
      final start = at(value['Start'] ?? '');
      final end = at(value['End'] ?? '');
      if (start == null || end == null) continue;
      final body = value['Text']!
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(r'\N', '\n')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\h', ' ')
          .trim();
      if (body.isNotEmpty) cues.add(Cue(start, end, body));
    }
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

/// Writes cues as SRT.
String writeSrt(List<Cue> cues) {
  String ts(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:'
        '${two(d.inSeconds % 60)},$ms';
  }

  final b = StringBuffer();
  for (var i = 0; i < cues.length; i++) {
    b
      ..writeln(i + 1)
      ..writeln('${ts(cues[i].start)} --> ${ts(cues[i].end)}')
      ..writeln(cues[i].text)
      ..writeln();
  }
  return b.toString();
}
