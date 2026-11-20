import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Fonts mpv's subtitle renderer (libass) uses (task 7.1).
///
/// On Android libass can't see the system fonts, so text subtitles (SRT,
/// ASS, VTT) were selected but drew nothing; image subtitles (PGS) still
/// showed. Kyndrel's own fonts are copied to a folder mpv reads
/// (`sub-fonts-dir`): Inter, and Noto Sans Arabic for Arabic subtitles.
abstract final class SubtitleFonts {
  static const assets = [
    'assets/fonts/Inter.ttf',
    'assets/fonts/NotoSansArabic.ttf',
  ];

  /// Copies the fonts into `<supportDir>/subfonts` (once per app version:
  /// unchanged files are left alone) and returns that folder.
  static Future<String> prepare(
    Directory supportDir, {
    AssetBundle? bundle,
  }) async {
    final dir = Directory(p.join(supportDir.path, 'subfonts'))
      ..createSync(recursive: true);
    for (final asset in assets) {
      final data = await (bundle ?? rootBundle).load(asset);
      final file = File(p.join(dir.path, p.basename(asset)));
      if (file.existsSync() && file.lengthSync() == data.lengthInBytes) {
        continue;
      }
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return dir.path;
  }
}

/// The folder from [SubtitleFonts.prepare]; set in `main.dart`, null in
/// tests.
final subtitleFontsDirProvider = Provider<String?>((ref) => null);
