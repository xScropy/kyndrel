import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/subtitles/subtitle_encoding.dart';
import 'package:kyndrel/core/subtitles/subtitle_prepare.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_player_backend.dart';

/// Task 9.5: subtitles in old encodings read correctly.
void main() {
  const arabic =
      '1\n00:00:01,000 --> 00:00:03,000\nمرحبا بالعالم، هذا هو الفيلم\n\n'
      '2\n00:00:04,000 --> 00:00:06,000\nأنا لا أعرف ما الذي كان هنا\n';

  /// Windows-1256 bytes of [s] (Arabic letters and ASCII only).
  Uint8List cp1256(String s) {
    const arabicLetters = {
      'ء': 0xC1, 'آ': 0xC2, 'أ': 0xC3, 'ؤ': 0xC4, 'إ': 0xC5, 'ئ': 0xC6, //
      'ا': 0xC7, 'ب': 0xC8, 'ة': 0xC9, 'ت': 0xCA, 'ث': 0xCB, 'ج': 0xCC,
      'ح': 0xCD, 'خ': 0xCE, 'د': 0xCF, 'ذ': 0xD0, 'ر': 0xD1, 'ز': 0xD2,
      'س': 0xD3, 'ش': 0xD4, 'ص': 0xD5, 'ض': 0xD6, 'ط': 0xD8, 'ظ': 0xD9,
      'ع': 0xDA, 'غ': 0xDB, 'ف': 0xDD, 'ق': 0xDE, 'ك': 0xDF, 'ل': 0xE1,
      'م': 0xE3, 'ن': 0xE4, 'ه': 0xE5, 'و': 0xE6, 'ى': 0xEC, 'ي': 0xED,
      '،': 0xA1,
    };
    return Uint8List.fromList([
      for (final r in s.runes)
        if (r < 0x80) r else arabicLetters[String.fromCharCode(r)]!,
    ]);
  }

  test('Windows-1256 Arabic is found, with or without a language', () {
    final bytes = cp1256(arabic);
    for (final lang in ['ar', null]) {
      final r = SubtitleEncoding.decode(bytes, lang: lang);
      expect(r.encoding, 'windows-1256', reason: '$lang');
      expect(r.text, arabic);
      expect(r.healthy, isTrue);
    }
  });

  test('UTF-8 stays UTF-8; byte-order marks win', () {
    final utf = Uint8List.fromList(utf8.encode(arabic));
    expect(SubtitleEncoding.decode(utf, lang: 'ar').encoding, 'utf-8');
    expect(SubtitleEncoding.decode(utf).text, arabic);

    final bom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf]);
    expect(SubtitleEncoding.decode(bom).text, arabic);

    final units = arabic.codeUnits;
    final le = Uint8List.fromList([
      0xFF,
      0xFE,
      for (final u in units) ...[u & 0xFF, u >> 8],
    ]);
    final r = SubtitleEncoding.decode(le);
    expect((r.encoding, r.text), ('utf-16le', arabic));
  });

  test('Latin text in Windows-1252 keeps its accents', () {
    const french =
        '1\n00:00:01,000 --> 00:00:02,000\nÇa va très bien, déjà vu\n';
    final bytes = Uint8List.fromList(latin1.encode(french));
    final r = SubtitleEncoding.decode(bytes, lang: 'fr');
    expect(r.encoding, 'windows-1252');
    expect(r.text, french);
  });

  test('a declared encoding is preferred; nonsense is unhealthy', () {
    final bytes = cp1256(arabic);
    expect(
      SubtitleEncoding.decode(bytes, encoding: 'cp1256').encoding,
      'windows-1256',
    );
    final noise = Uint8List.fromList([for (var i = 0; i < 400; i++) i % 32]);
    expect(SubtitleEncoding.decode(noise).healthy, isFalse);
  });

  test('a Windows-1256 file reaches mpv as a UTF-8 copy, once', () {
    final dir = Directory.systemTemp.createTempSync('kyndrel_subs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = Directory(p.join(dir.path, 'cache'));
    final old = File(p.join(dir.path, 'film.ar.srt'))
      ..writeAsBytesSync(cp1256(arabic));
    final ready = prepareSubtitleFile(old.path, cache: cache, lang: 'ar');
    expect(ready, isNot(old.path));
    expect(p.extension(ready), '.srt');
    expect(File(ready).readAsStringSync(), arabic);
    expect(prepareSubtitleFile(old.path, cache: cache), ready);
    expect(readSubtitleText(old.path), arabic);

    // UTF-8 files, URLs and pictures stay as they are.
    final good = File(p.join(dir.path, 'film.en.srt'))
      ..writeAsStringSync(arabic);
    expect(prepareSubtitleFile(good.path, cache: cache), good.path);
    const url = 'https://x/sub.srt';
    expect(prepareSubtitleFile(url, cache: cache), url);
    expect(
      prepareSubtitleFile('/x/missing.srt', cache: cache),
      '/x/missing.srt',
    );
    expect(prepareSubtitleFile('/x/film.sup', cache: cache), '/x/film.sup');
  });

  test("mpv's own guess: Windows-1256 when Arabic is wanted", () {
    expect(const AppSettings().subtitleCodepage, 'auto');
    expect(
      const AppSettings(subtitleLanguages: 'en, ar').subtitleCodepage,
      'cp1256',
    );
    expect(const AppSettings(language: 'ar').subtitleCodepage, 'cp1256');
  });

  test('sound descriptions and subtitle frame rate reach mpv', () async {
    final backend = FakePlayerBackend();
    final service = PlayerService(backend);
    addTearDown(service.dispose);
    await service.setHideSoundDescriptions(enabled: true);
    expect(backend.properties['sub-filter-sdh'], 'yes');
    await service.setSubtitleFps(25);
    expect(backend.properties['sub-fps'], '25.000');
    expect(service.subtitleFps, 25);
    // A new file starts with the subtitle's own timing.
    await service.open('/v/next.mkv');
    expect(backend.properties['sub-fps'], '0');
    expect(service.subtitleFps, isNull);
  });
}
