import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';

/// `--perf-log` (task 5.4): machine-readable timings and memory on stderr,
/// read by `scripts/perf_probe.sh`. Each line is
/// `kyndrel-perf <event> <epoch ms> [value]`.
abstract final class PerfLog {
  static bool enabled = false;

  static void mark(String event, [Object? value]) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    stderr.writeln('kyndrel-perf $event $now${value == null ? '' : ' $value'}');
  }

  /// First Flutter frame, first decoded video frame, then RSS, mpv's
  /// dropped-frame count and measured fps every 10 s.
  static void start(WidgetRef ref) {
    if (!enabled) return;
    unawaited(
      SchedulerBinding.instance.endOfFrame.then((_) => mark('first-frame')),
    );
    var sawVideo = false;
    ref.listenManual(playbackStateProvider, (_, next) {
      final s = next.value;
      if (!sawVideo && (s?.videoWidth ?? 0) > 0) {
        sawVideo = true;
        mark('first-video-frame');
      }
    });
    final service = ref.read(playerServiceProvider);
    Timer.periodic(const Duration(seconds: 10), (_) async {
      mark('rss-mb', (ProcessInfo.currentRss / 1048576).round());
      final d = await service.diagnostics();
      mark('dropped-frames', d['frame-drop-count'] ?? 0);
      if (d['estimated-vf-fps'] case final fps?) mark('fps', fps);
    });
  }
}
