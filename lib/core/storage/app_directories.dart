import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App cache folder (downloaded subtitles...). Overridden in `main.dart`
/// with `getApplicationCacheDirectory()` and in tests with a temp folder.
final appCacheDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('appCacheDirProvider not overridden'),
);
