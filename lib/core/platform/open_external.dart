import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a URL or file with the system's default handler.
typedef ExternalOpener = Future<void> Function(String target);

Future<void> openWithSystem(String target) async {
  if (Platform.isWindows) {
    // `start` treats the first quoted argument as a window title.
    await Process.run('cmd', ['/c', 'start', '', target]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [target]);
  } else {
    await Process.run('xdg-open', [target]);
  }
}

/// Overridden in tests to record what would be opened.
final externalOpenerProvider = Provider<ExternalOpener>(
  (ref) => openWithSystem,
);
