import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// What the app was asked to do on the command line.
///
/// `kyndrel [--diagnostics] [--perf-log] [file-or-url]`
@immutable
class LaunchOptions {
  const new({this.source, this.showDiagnostics = false, this.perfLog = false});

  /// A relative file path is resolved against [workingDirectory]; URLs
  /// and absolute paths are kept as they are.
  factory parse(List<String> args, {String? workingDirectory}) {
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
    if (source != null &&
        workingDirectory != null &&
        !RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(source) &&
        !p.isAbsolute(source)) {
      source = p.normalize(p.join(workingDirectory, source));
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
