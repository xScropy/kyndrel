import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:path/path.dart' as p;

/// What went wrong in the previous session.
@immutable
class CrashReport {
  const new({required this.unexpectedExit, this.error = '', this.log = ''});

  /// The process ended without closing normally (a native crash, a kill,
  /// a power cut): the session marker was still there.
  final bool unexpectedExit;

  /// The first uncaught Dart error and its stack, if there was one.
  final String error;

  /// The end of the previous session's log.
  final String log;
}

/// Notices crashes across launches (task 5.7).
///
/// `session.lock` is written at start and removed on a clean close; if it
/// is still there next time, the app did not close normally. Uncaught
/// errors also go to `last-error.txt`. Both are read once, at start.
class CrashMonitor {
  new(this.directory, this.log);

  final Directory? directory;
  final AppLog log;
  CrashReport? _previous;
  bool _errorWritten = false;

  File? _file(String name) =>
      directory == null ? null : File(p.join(directory!.path, name));

  /// The previous session's problem, or null if it ended cleanly.
  CrashReport? get previous => _previous;

  /// Reads what the last session left behind, then marks this one as
  /// running. Call before [AppLog] writes anything for this session.
  void start() {
    final lock = _file('session.lock');
    final error = _file('last-error.txt');
    if (lock == null || error == null) return;
    final crashed = lock.existsSync();
    final errorText = error.existsSync() ? error.readAsStringSync() : '';
    if (crashed || errorText.isNotEmpty) {
      _previous = CrashReport(
        unexpectedExit: crashed,
        error: errorText,
        log: _tail(log.file, 60),
      );
    }
    if (error.existsSync()) error.deleteSync();
    lock
      ..createSync(recursive: true)
      ..writeAsStringSync('$pid ${DateTime.now().toIso8601String()}');
  }

  /// An uncaught error: logged, and the first one kept for the next start.
  void recordError(Object error, StackTrace? stack, {String source = 'app'}) {
    log.error(source, 'Uncaught: $error\n$stack');
    if (_errorWritten) return;
    _errorWritten = true;
    try {
      _file('last-error.txt')?.writeAsStringSync('$error\n\n$stack');
    } on FileSystemException {
      // Best effort.
    }
  }

  /// The window is closing normally.
  void cleanExit() {
    try {
      final lock = _file('session.lock');
      if (lock != null && lock.existsSync()) lock.deleteSync();
    } on FileSystemException {
      // Best effort.
    }
  }

  /// The app went to the background (Android): the system may end the
  /// process there, which is not a crash, so mark the session as stopped
  /// cleanly until [resume].
  void pause() => cleanExit();

  /// Back in the foreground: running again.
  void resume() {
    try {
      _file('session.lock')
        ?..createSync(recursive: true)
        ..writeAsStringSync('$pid ${DateTime.now().toIso8601String()}');
    } on FileSystemException {
      // Best effort.
    }
  }

  /// Forget the previous crash (after offering a report once).
  void dismissPrevious() => _previous = null;

  static String _tail(File? f, int lines) {
    if (f == null || !f.existsSync()) return '';
    final all = f.readAsLinesSync();
    return all.sublist(all.length > lines ? all.length - lines : 0).join('\n');
  }
}

/// Overridden in `main.dart`.
final crashMonitorProvider = Provider<CrashMonitor>(
  (ref) => CrashMonitor(null, ref.watch(appLogProvider)),
);

/// A GitHub "new issue" link with the report filled in. Nothing is sent:
/// the user reads it in the browser and decides (task 5.7).
Uri crashIssueUrl({
  required String repository,
  required String version,
  required CrashReport report,
  String? os,
}) {
  final system =
      os ??
      '${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}';
  String fence(String s) => '```\n${s.trim()}\n```';
  var log = report.log.trim();
  final head = [
    '**What were you doing when it happened?**',
    '',
    '',
    '**Kyndrel** $version · **OS** $system',
    if (report.unexpectedExit) '_Kyndrel closed unexpectedly._',
    if (report.error.isNotEmpty) ...['', '**Error**', fence(report.error)],
  ].join('\n');
  // Browsers and GitHub cap URL length; keep the newest log lines.
  const maxBody = 6000;
  if (head.length + log.length > maxBody) {
    final keep = (maxBody - head.length).clamp(0, log.length);
    log = log.substring(log.length - keep);
  }
  final body = log.isEmpty ? head : '$head\n\n**Log**\n${fence(log)}';
  var firstLine = report.error.split('\n').first.trim();
  if (firstLine.length > 80) firstLine = firstLine.substring(0, 80);
  final title = firstLine.isEmpty
      ? 'Crash: Kyndrel closed unexpectedly'
      : 'Crash: $firstLine';
  return Uri.https('github.com', '/$repository/issues/new', {
    'title': title,
    'labels': 'crash',
    'body': body,
  });
}
