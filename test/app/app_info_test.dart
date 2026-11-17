import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/app_info.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final v = RegExp(
      r'^version:\s*([\d.]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, v);
  });
}
