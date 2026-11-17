import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';

/// Runs before every test file: loads the real fonts so goldens show Inter
/// text and Material icon glyphs instead of placeholder boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont(KyndrelTokens.fontFamily, 'assets/fonts/Inter.ttf');
  await _loadFont(
    KyndrelTokens.fontFamilyFallback.first,
    'assets/fonts/NotoSansArabic.ttf',
  );
  await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
  await testMain();
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
