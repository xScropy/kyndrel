import 'package:flutter/foundation.dart';

/// What the app was asked to do on the command line.
///
/// `kyndrel [--diagnostics] [--perf-log] [file-or-url]`
@immutable
class LaunchOptions {
  const new({this.source, this.showDiagnostics = false, this.perfLog = false});

  factory parse(List<String> args) {
    String? source;
    var diagnostics = false;
    var perfLog = false;
    for (final arg in args) {
      if (arg == '--diagnostics') {
        diagnostics = true;
      } else if (arg == '--perf-log') {
        perfLog = true;
      } else if (!arg.startsWith('--') && source == null && arg.isNotEmpty) {
        source = arg;
      }
    }
    return LaunchOptions(
      source: source,
      showDiagnostics: diagnostics,
      perfLog: perfLog,
    );
  }

  /// File path or URL to open on start.
  final String? source;

  /// Show the mpv diagnostics overlay (decoder, codec, fps, dropped frames).
  final bool showDiagnostics;

  /// Print startup timings and memory for `scripts/perf_probe.sh`.
  final bool perfLog;
}
