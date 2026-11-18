import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';

void main() {
  test('no arguments', () {
    final o = LaunchOptions.parse(const []);
    expect(o.source, isNull);
    expect(o.showDiagnostics, isFalse);
  });

  test('first non-flag argument is the source, flags anywhere', () {
    final o = LaunchOptions.parse(const [
      '--diagnostics',
      r'C:\a b.mkv',
      'second.mp4',
    ]);
    expect(o.source, r'C:\a b.mkv');
    expect(o.showDiagnostics, isTrue);
    expect(o.perfLog, isFalse);
  });

  test('--perf-log', () {
    final o = LaunchOptions.parse(const ['--perf-log', 'x.mp4']);
    expect(o.perfLog, isTrue);
    expect(o.source, 'x.mp4');
  });

  test('unknown flags are ignored', () {
    final o = LaunchOptions.parse(const ['--verbose', 'x.mp4']);
    expect(o.source, 'x.mp4');
    expect(o.showDiagnostics, isFalse);
  });
}
