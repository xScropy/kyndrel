import 'dart:io';

import 'package:kyndrel/core/subtitles/subtitle_encoding.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:path/path.dart' as p;

/// Text subtitle files Kyndrel reads itself and hands to mpv as UTF-8.
const textSubtitleExtensions = {'.srt', '.vtt', '.ass', '.ssa', '.sub', '.txt'};

/// Small files, read synchronously (a subtitle is rarely over 200 KB).
///
/// Returns a path mpv can read for the subtitle file at [path] (task 9.5).
///
/// UTF-8 files are used as they are. Others (Windows-1256 Arabic,
/// UTF-16, Latin accents) are decoded with [SubtitleEncoding] and written
/// once as UTF-8 under [cache]; mpv's own guess would show `ÇáÓáÇã` for old
/// Arabic files when its build has no charset detector. URLs, image
/// subtitles and unreadable files come back unchanged.
String prepareSubtitleFile(
  String path, {
  required Directory cache,
  String? lang,
}) {
  if (path.contains('://') && !path.startsWith('file://')) return path;
  final local = path.startsWith('file://')
      ? Uri.parse(path).toFilePath()
      : path;
  final ext = p.extension(local).toLowerCase();
  if (!textSubtitleExtensions.contains(ext)) return path;
  try {
    final file = File(local);
    final bytes = file.readAsBytesSync();
    final r = SubtitleEncoding.decode(bytes, lang: lang);
    if (r.encoding == 'utf-8' && !_hasBom(bytes)) return path;
    final stat = file.statSync();
    final key = fnv1a64(
      '$local|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
    );
    final out = File(p.join(cache.path, 'subtitles_utf8', '$key$ext'));
    if (!out.existsSync()) {
      out.parent.createSync(recursive: true);
      File('${out.path}.part')
        ..writeAsStringSync(r.text, flush: true)
        ..renameSync(out.path);
    }
    return out.path;
  } on FileSystemException {
    return path;
  }
}

bool _hasBom(List<int> b) =>
    b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF;

/// The text of the subtitle file at [path] in whatever encoding it uses
/// (task 9.5).
String readSubtitleText(String path, {String? lang}) =>
    SubtitleEncoding.decode(File(path).readAsBytesSync(), lang: lang).text;
