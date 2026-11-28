import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Decodes subtitle bytes in whatever encoding they came in (task 9.5,
/// Harbor's `subtitles/encoding.ts`): a byte-order mark wins; valid UTF-8
/// is UTF-8; otherwise Windows-1256, ISO-8859-6 and Windows-1252 are tried
/// and scored on printable text, mojibake, control characters, timestamps
/// and, for Arabic, how Arabic the words look. Old Arabic subtitles are
/// mostly Windows-1256 and show as `ÇáÓáÇã` when read as Latin-1.
@immutable
class SubtitleDecodeResult {
  const new({
    required this.text,
    required this.encoding,
    required this.score,
    required this.healthy,
    this.ambiguous = false,
  });

  final String text;

  /// `utf-8`, `utf-16le`, `utf-16be`, `windows-1256`, `iso-8859-6` or
  /// `windows-1252`.
  final String encoding;

  /// 0–1: how much the text looks like a readable subtitle.
  final double score;

  /// Good enough to show without a warning.
  final bool healthy;

  /// Arabic in two legacy encodings that score the same.
  final bool ambiguous;
}

abstract final class SubtitleEncoding {
  static const healthyScore = 0.72;

  static const _arabicWords = {
    'أنا', 'أنت', 'إلى', 'الآن', 'التي', 'الذي', 'السلام', 'الله', 'في', //
    'كان', 'لا', 'لكن', 'لم', 'لن', 'ما', 'من', 'هذا', 'هذه', 'هو', 'هي',
    'وهو', 'يا', 'سلام', 'عالم', 'العالم', 'بالعالم', 'مرحبا',
  };
  static const _arabicSequences = [
    'ال', 'لا', 'بال', 'وال', 'لل', 'من', 'في', 'على', 'إلى', 'أن', 'إن', //
    'ما', 'هو', 'هي', 'هذا', 'هذه', 'كان', 'مر', 'رح', 'حب', 'عا', 'عال',
    'الم',
  ];

  static bool isArabicLanguage(String? lang) {
    final l = (lang ?? '').trim().toLowerCase().replaceAll('_', '-');
    return l == 'ar' || l == 'ara' || l == 'arabic' || l.startsWith('ar-');
  }

  /// Decodes [bytes]. [lang] (e.g. `ar`) and [encoding] (declared by the
  /// source) steer the guess.
  static SubtitleDecodeResult decode(
    Uint8List bytes, {
    String? lang,
    String? encoding,
  }) {
    final bom = _bom(bytes);
    var validUtf8 = false;
    if (bom == null || bom.$1 == 'utf-8') {
      try {
        utf8.decode(bom == null ? bytes : bytes.sublist(3));
        validUtf8 = true;
      } on FormatException {
        // Not UTF-8.
      }
    }
    if (bom != null) {
      final text = _decodeAs(bytes.sublist(bom.$2), bom.$1)!;
      final c = _assess(text, bom.$1, lang, encoding, validUtf8);
      return SubtitleDecodeResult(
        text: text,
        encoding: bom.$1,
        score: c.score,
        healthy: c.healthy,
      );
    }
    final requested = encoding == null ? null : _normalize(encoding);
    final legacy = isArabicLanguage(lang)
        ? const ['windows-1256', 'iso-8859-6', 'windows-1252']
        : const ['windows-1252', 'windows-1256', 'iso-8859-6'];
    final names = <String>{?requested, 'utf-8', ...legacy};
    final candidates = <_Candidate>[];
    for (final name in names) {
      final text = _decodeAs(bytes, name);
      if (text != null) {
        candidates.add(_assess(text, name, lang, encoding, validUtf8));
      }
    }
    final _Candidate best;
    if (validUtf8) {
      best = candidates.firstWhere((c) => c.encoding == 'utf-8');
    } else {
      candidates.sort((a, b) => b.score.compareTo(a.score));
      best = candidates.first;
    }
    var ambiguous = false;
    if (encoding == null && !validUtf8 && isArabicLanguage(lang)) {
      final w = candidates.where((c) => c.encoding == 'windows-1256');
      final i = candidates.where((c) => c.encoding == 'iso-8859-6');
      ambiguous =
          w.isNotEmpty &&
          i.isNotEmpty &&
          w.first.text != i.first.text &&
          (w.first.score - i.first.score).abs() < 0.012;
    }
    return SubtitleDecodeResult(
      text: best.text,
      encoding: best.encoding,
      score: best.score,
      healthy: !ambiguous && best.healthy,
      ambiguous: ambiguous,
    );
  }

  static (String, int)? _bom(Uint8List b) {
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return ('utf-16le', 2);
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return ('utf-16be', 2);
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      return ('utf-8', 3);
    }
    return null;
  }

  static String _normalize(String v) {
    final n = v.trim().toLowerCase().replaceAll('_', '-');
    return switch (n) {
      'utf8' => 'utf-8',
      'utf16le' || 'utf-16' => 'utf-16le',
      'utf16be' => 'utf-16be',
      'cp1256' || 'windows1256' => 'windows-1256',
      'cp1252' || 'windows1252' => 'windows-1252',
      'iso8859-6' || 'iso-8859-6-i' => 'iso-8859-6',
      _ => n,
    };
  }

  static String? _decodeAs(List<int> bytes, String encoding) {
    switch (encoding) {
      case 'utf-8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'utf-16le' || 'utf-16be':
        final le = encoding == 'utf-16le';
        final units = <int>[
          for (var i = 0; i + 1 < bytes.length; i += 2)
            if (le)
              bytes[i] | bytes[i + 1] << 8
            else
              bytes[i] << 8 | bytes[i + 1],
        ];
        return String.fromCharCodes(units);
      case 'windows-1256':
        return _single(bytes, _Tables.windows1256);
      case 'iso-8859-6':
        return _single(bytes, _Tables.iso88596);
      case 'windows-1252':
        return _single(bytes, _Tables.windows1252);
    }
    return null;
  }

  static String _single(List<int> bytes, List<int> high) =>
      String.fromCharCodes([
        for (final b in bytes)
          if (b < 0x80) b else high[b - 0x80],
      ]);

  static bool _isControl(int c) =>
      c != 0x0A &&
      c != 0x0D &&
      c != 0x09 &&
      (c < 0x20 || (c >= 0x7F && c <= 0x9F));

  static final _space = RegExp(r'\s');
  static final _mojibake = RegExp('(?:Ã.|Â.|â.|Ø.|Ù.)');
  static final _srtTime = RegExp(r'\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}\s*-->');
  static final _assTime = RegExp(
    r'^Dialogue:[^\n]*,\d+:\d{2}:\d{2}\.\d{1,3},',
    multiLine: true,
    caseSensitive: false,
  );
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _arabic = RegExp(r'\p{Script=Arabic}', unicode: true);
  static final _arabicWord = RegExp(r'\p{Script=Arabic}{2,}', unicode: true);
  static final _harakat = RegExp('[ؐ-ؚـً-ٰٟۖ-ۭ]');

  static double _arabicPlausibility(String text) {
    final words = _arabicWord
        .allMatches(text.replaceAll(_harakat, ''))
        .map((m) => m[0]!)
        .toList();
    if (words.isEmpty) return 0;
    final common = words.where(_arabicWords.contains).length / words.length;
    final joined = words.join(' ');
    var hits = 0;
    for (final s in _arabicSequences) {
      hits += s.allMatches(joined).length;
    }
    final density = (hits / (joined.length / 3).clamp(2, double.infinity))
        .clamp(0.0, 1.0);
    return common * 0.7 + density * 0.3;
  }

  static _Candidate _assess(
    String text,
    String encoding,
    String? lang,
    String? declared,
    bool validUtf8,
  ) {
    final runes = text.runes.toList();
    var content = 0;
    var printable = 0;
    var replacement = 0;
    var control = 0;
    for (final r in runes) {
      if (_isControl(r)) control++;
      if (r == 0xFFFD) replacement++;
      if (_space.hasMatch(String.fromCharCode(r))) continue;
      content++;
      if (r != 0xFFFD && !_isControl(r)) printable++;
    }
    final denominator = content < 1 ? 1 : content;
    final printableRatio = printable / denominator;
    final mojibake = _mojibake.allMatches(text).length;
    final timestamps =
        _srtTime.allMatches(text).length + _assTime.allMatches(text).length;
    final letters = _letter.allMatches(text).length;
    final arabicRatio =
        _arabic.allMatches(text).length / (letters < 1 ? 1 : letters);
    final arabicLanguage = isArabicLanguage(lang);
    final otherLanguage = (lang?.trim().isNotEmpty ?? false) && !arabicLanguage;

    var score = 0.16 + printableRatio * 0.64;
    if (replacement > 0) {
      score -= 0.32 + (replacement / denominator).clamp(0, 0.4);
    }
    score -= (control / (runes.isEmpty ? 1 : runes.length) * 6).clamp(0, 0.5);
    score -= (mojibake / denominator * 8).clamp(0, 0.35);
    if (timestamps > 0) score += 0.06;
    if ((lang?.trim().isEmpty ?? true) && arabicRatio >= 0.25) score += 0.03;
    if (otherLanguage && arabicRatio >= 0.25) score -= 0.08;
    if (declared != null && _normalize(declared) == encoding) score += 0.07;
    if (encoding == 'utf-8' && validUtf8) score += 0.08;
    if (arabicLanguage) {
      if (arabicRatio >= 0.25) {
        score += 0.05;
      } else if (letters >= 8) {
        score -= 0.18;
      }
      if (letters >= 8) score -= (1 - arabicRatio) * 0.08;
      score += _arabicPlausibility(text) * 0.08;
    }
    score = score.clamp(0.0, 1.0);
    return _Candidate(
      text,
      encoding,
      score,
      healthy: score >= healthyScore && replacement == 0 && control == 0,
    );
  }
}

class _Candidate {
  new(this.text, this.encoding, this.score, {required this.healthy});

  final String text;
  final String encoding;
  final double score;
  final bool healthy;
}

/// Bytes 0x80–0xFF of the single-byte encodings (from Python's codecs).
abstract final class _Tables {
  static const windows1256 = <int>[
    0x20AC,
    0x067E,
    0x201A,
    0x0192,
    0x201E,
    0x2026,
    0x2020,
    0x2021,
    0x02C6,
    0x2030,
    0x0679,
    0x2039,
    0x0152,
    0x0686,
    0x0698,
    0x0688,
    0x06AF,
    0x2018,
    0x2019,
    0x201C,
    0x201D,
    0x2022,
    0x2013,
    0x2014,
    0x06A9,
    0x2122,
    0x0691,
    0x203A,
    0x0153,
    0x200C,
    0x200D,
    0x06BA,
    0x00A0,
    0x060C,
    0x00A2,
    0x00A3,
    0x00A4,
    0x00A5,
    0x00A6,
    0x00A7,
    0x00A8,
    0x00A9,
    0x06BE,
    0x00AB,
    0x00AC,
    0x00AD,
    0x00AE,
    0x00AF,
    0x00B0,
    0x00B1,
    0x00B2,
    0x00B3,
    0x00B4,
    0x00B5,
    0x00B6,
    0x00B7,
    0x00B8,
    0x00B9,
    0x061B,
    0x00BB,
    0x00BC,
    0x00BD,
    0x00BE,
    0x061F,
    0x06C1,
    0x0621,
    0x0622,
    0x0623,
    0x0624,
    0x0625,
    0x0626,
    0x0627,
    0x0628,
    0x0629,
    0x062A,
    0x062B,
    0x062C,
    0x062D,
    0x062E,
    0x062F,
    0x0630,
    0x0631,
    0x0632,
    0x0633,
    0x0634,
    0x0635,
    0x0636,
    0x00D7,
    0x0637,
    0x0638,
    0x0639,
    0x063A,
    0x0640,
    0x0641,
    0x0642,
    0x0643,
    0x00E0,
    0x0644,
    0x00E2,
    0x0645,
    0x0646,
    0x0647,
    0x0648,
    0x00E7,
    0x00E8,
    0x00E9,
    0x00EA,
    0x00EB,
    0x0649,
    0x064A,
    0x00EE,
    0x00EF,
    0x064B,
    0x064C,
    0x064D,
    0x064E,
    0x00F4,
    0x064F,
    0x0650,
    0x00F7,
    0x0651,
    0x00F9,
    0x0652,
    0x00FB,
    0x00FC,
    0x200E,
    0x200F,
    0x06D2,
  ];

  static const iso88596 = <int>[
    0x0080,
    0x0081,
    0x0082,
    0x0083,
    0x0084,
    0x0085,
    0x0086,
    0x0087,
    0x0088,
    0x0089,
    0x008A,
    0x008B,
    0x008C,
    0x008D,
    0x008E,
    0x008F,
    0x0090,
    0x0091,
    0x0092,
    0x0093,
    0x0094,
    0x0095,
    0x0096,
    0x0097,
    0x0098,
    0x0099,
    0x009A,
    0x009B,
    0x009C,
    0x009D,
    0x009E,
    0x009F,
    0x00A0,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0x00A4,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0x060C,
    0x00AD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0x061B,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0x061F,
    0xFFFD,
    0x0621,
    0x0622,
    0x0623,
    0x0624,
    0x0625,
    0x0626,
    0x0627,
    0x0628,
    0x0629,
    0x062A,
    0x062B,
    0x062C,
    0x062D,
    0x062E,
    0x062F,
    0x0630,
    0x0631,
    0x0632,
    0x0633,
    0x0634,
    0x0635,
    0x0636,
    0x0637,
    0x0638,
    0x0639,
    0x063A,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0x0640,
    0x0641,
    0x0642,
    0x0643,
    0x0644,
    0x0645,
    0x0646,
    0x0647,
    0x0648,
    0x0649,
    0x064A,
    0x064B,
    0x064C,
    0x064D,
    0x064E,
    0x064F,
    0x0650,
    0x0651,
    0x0652,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
    0xFFFD,
  ];

  static const windows1252 = <int>[
    0x20AC,
    0xFFFD,
    0x201A,
    0x0192,
    0x201E,
    0x2026,
    0x2020,
    0x2021,
    0x02C6,
    0x2030,
    0x0160,
    0x2039,
    0x0152,
    0xFFFD,
    0x017D,
    0xFFFD,
    0xFFFD,
    0x2018,
    0x2019,
    0x201C,
    0x201D,
    0x2022,
    0x2013,
    0x2014,
    0x02DC,
    0x2122,
    0x0161,
    0x203A,
    0x0153,
    0xFFFD,
    0x017E,
    0x0178,
    0x00A0,
    0x00A1,
    0x00A2,
    0x00A3,
    0x00A4,
    0x00A5,
    0x00A6,
    0x00A7,
    0x00A8,
    0x00A9,
    0x00AA,
    0x00AB,
    0x00AC,
    0x00AD,
    0x00AE,
    0x00AF,
    0x00B0,
    0x00B1,
    0x00B2,
    0x00B3,
    0x00B4,
    0x00B5,
    0x00B6,
    0x00B7,
    0x00B8,
    0x00B9,
    0x00BA,
    0x00BB,
    0x00BC,
    0x00BD,
    0x00BE,
    0x00BF,
    0x00C0,
    0x00C1,
    0x00C2,
    0x00C3,
    0x00C4,
    0x00C5,
    0x00C6,
    0x00C7,
    0x00C8,
    0x00C9,
    0x00CA,
    0x00CB,
    0x00CC,
    0x00CD,
    0x00CE,
    0x00CF,
    0x00D0,
    0x00D1,
    0x00D2,
    0x00D3,
    0x00D4,
    0x00D5,
    0x00D6,
    0x00D7,
    0x00D8,
    0x00D9,
    0x00DA,
    0x00DB,
    0x00DC,
    0x00DD,
    0x00DE,
    0x00DF,
    0x00E0,
    0x00E1,
    0x00E2,
    0x00E3,
    0x00E4,
    0x00E5,
    0x00E6,
    0x00E7,
    0x00E8,
    0x00E9,
    0x00EA,
    0x00EB,
    0x00EC,
    0x00ED,
    0x00EE,
    0x00EF,
    0x00F0,
    0x00F1,
    0x00F2,
    0x00F3,
    0x00F4,
    0x00F5,
    0x00F6,
    0x00F7,
    0x00F8,
    0x00F9,
    0x00FA,
    0x00FB,
    0x00FC,
    0x00FD,
    0x00FE,
    0x00FF,
  ];
}
