import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

enum LogLevel { debug, info, warn, error }

@immutable
class LogRecord {
  const new(this.time, this.level, this.source, this.message);

  final DateTime time;
  final LogLevel level;

  /// Where it came from: `app`, `mpv/<module>`, `flutter`.
  final String source;
  final String message;

  String format() {
    final t = time.toUtc().toIso8601String();
    return '$t ${level.name.toUpperCase().padRight(5)} [$source] $message';
  }
}

/// The app's log (task 5.7): the last [capacity] records in memory for the
/// log viewer, and the same lines appended to `logs/kyndrel.log` in the
/// app support folder. When the file passes [maxFileBytes] it moves to
/// `kyndrel.1.log` (one previous file is kept).
class AppLog {
  new({this.directory, this.capacity = 2000, this.maxFileBytes = 1 << 20});

  /// Where `kyndrel.log` lives; null keeps the log in memory only (tests).
  final Directory? directory;
  final int capacity;
  final int maxFileBytes;

  final _records = ListQueue<LogRecord>();
  final _changes = StreamController<LogRecord>.broadcast();
  RandomAccessFile? _file;
  int _fileBytes = 0;

  File? get file =>
      directory == null ? null : File(p.join(directory!.path, 'kyndrel.log'));
  File? get previousFile =>
      directory == null ? null : File(p.join(directory!.path, 'kyndrel.1.log'));

  List<LogRecord> get records => List.unmodifiable(_records);
  Stream<LogRecord> get changes => _changes.stream;

  void debug(String source, String message) =>
      add(LogLevel.debug, source, message);
  void info(String source, String message) =>
      add(LogLevel.info, source, message);
  void warn(String source, String message) =>
      add(LogLevel.warn, source, message);
  void error(String source, String message) =>
      add(LogLevel.error, source, message);

  void add(LogLevel level, String source, String message) {
    final r = LogRecord(DateTime.now(), level, source, message.trimRight());
    _records.addLast(r);
    while (_records.length > capacity) {
      _records.removeFirst();
    }
    _write(r);
    if (!_changes.isClosed) _changes.add(r);
  }

  /// The last [lines] records as text (bug reports, "Copy log").
  String tail([int lines = 200]) {
    final list = _records.toList();
    final start = list.length > lines ? list.length - lines : 0;
    return list.sublist(start).map((r) => r.format()).join('\n');
  }

  void _write(LogRecord r) {
    final f = file;
    if (f == null) return;
    try {
      if (_file == null) {
        f.parent.createSync(recursive: true);
        _file = f.openSync(mode: FileMode.append);
        _fileBytes = _file!.lengthSync();
      }
      if (_fileBytes > maxFileBytes) _rotate();
      final line = utf8.encode('${r.format()}\n');
      _file!.writeFromSync(line);
      _fileBytes += line.length;
    } on FileSystemException {
      // A log that can't be written must never take the app down.
      _file = null;
    }
  }

  void _rotate() {
    _file?.closeSync();
    _file = null;
    final f = file!;
    final old = previousFile!;
    if (old.existsSync()) old.deleteSync();
    f.renameSync(old.path);
    _file = f.openSync(mode: FileMode.append);
    _fileBytes = 0;
  }

  Future<void> close() async {
    _file?.closeSync();
    _file = null;
    await _changes.close();
  }
}

/// Overridden in `main.dart` with the file-backed log.
final appLogProvider = Provider<AppLog>((ref) => AppLog());
