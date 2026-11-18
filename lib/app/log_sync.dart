import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:kyndrel/core/player/player_providers.dart';

/// Copies mpv's warnings and errors into the app log (task 5.7).
final logSyncProvider = Provider<void>((ref) {
  final log = ref.watch(appLogProvider);
  final sub = ref.watch(playerServiceProvider).logLines.listen((line) {
    final level = switch (line.level) {
      'fatal' || 'error' => LogLevel.error,
      'warn' => LogLevel.warn,
      'info' || 'v' => LogLevel.info,
      _ => LogLevel.debug,
    };
    log.add(level, 'mpv/${line.prefix}', line.text);
  });
  ref.onDispose(() => unawaited(sub.cancel()));
});
