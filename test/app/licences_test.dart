import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/licences.dart';

void main() {
  test('fonts and libmpv/FFmpeg are on the licence page (task 5.8)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerBundledLicences();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();
    expect(packages, containsAll(['Inter', 'Noto Sans Arabic', 'libmpv']));
    final inter = entries.firstWhere((e) => e.packages.contains('Inter'));
    expect(
      inter.paragraphs.map((p) => p.text).join(' '),
      contains('SIL OPEN FONT LICENSE'),
    );
    expect(mpvNotice, contains('libmpv-win32-video-build'));
  });
}
