import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a URL or file with the system's default handler.
typedef ExternalOpener = Future<void> Function(String target);

/// Android: a VIEW intent from `MainActivity.kt` (task 6.1).
const _androidChannel = MethodChannel('kyndrel/open_external');

Future<void> openWithSystem(String target) async {
  if (Platform.isAndroid) {
    await _androidChannel.invokeMethod<void>('open', target);
  } else if (Platform.isWindows) {
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
