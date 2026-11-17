import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/core/utils/time_format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatDuration(const Duration(seconds: -90)), '-1:30');
  });

  test('formatRate', () {
    expect(formatRate(1), '1×');
    expect(formatRate(1.25), '1.25×');
    expect(formatRate(0.5), '0.5×');
    expect(formatRate(2), '2×');
  });

  test('formatRemaining', () {
    expect(formatRemaining(const Duration(minutes: 75)), '1 h 15 min');
    expect(formatRemaining(const Duration(minutes: 12)), '12 min');
    expect(formatRemaining(const Duration(seconds: 40)), '40 s');
  });

  test('languageName', () {
    expect(languageName('eng'), 'English');
    expect(languageName('en'), 'English');
    expect(languageName('ara'), 'Arabic');
    expect(languageName('fre'), 'French');
    expect(languageName('fra'), 'French');
    expect(languageName('ger'), 'German');
    expect(languageName('chi'), 'Chinese');
    expect(languageName('pt-BR'), 'Portuguese (Brazil)');
    expect(languageName('zh-TW'), 'Chinese (Traditional)');
    expect(languageName('und'), 'Unknown');
    expect(languageName(null), 'Unknown');
    expect(languageName('xyz'), 'XYZ');
  });

  test('languageCode2', () {
    expect(languageCode2('eng'), 'en');
    expect(languageCode2('ar'), 'ar');
    expect(languageCode2('pt-BR'), 'pt');
    expect(languageCode2('zzz'), isNull);
  });
}
