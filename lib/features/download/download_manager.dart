import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

enum DownloadStatus { queued, running, paused, done, failed, cancelled }

@immutable
class DownloadTask {
  const new({
    required this.id,
    required this.url,
    required this.path,
    this.status = DownloadStatus.queued,
    this.received = 0,
    this.total,
    this.error,
    this.viaYtDlp = false,
  });

  final int id;
  final String url;

  /// Final file path (while running: `<path>.part`).
  final String path;
  final DownloadStatus status;
  final int received;
  final int? total;
  final String? error;

  /// Downloaded by the optional yt-dlp plugin instead of plain HTTP.
  final bool viaYtDlp;

  double? get progress =>
      total == null || total == 0 ? null : (received / total!).clamp(0.0, 1.0);

  String get fileName => p.basename(path);

  DownloadTask copyWith({
    DownloadStatus? status,
    int? received,
    int? Function()? total,
    String? Function()? error,
    String? path,
  }) => DownloadTask(
    id: id,
    url: url,
    path: path ?? this.path,
    status: status ?? this.status,
    received: received ?? this.received,
    total: total != null ? total() : this.total,
    error: error != null ? error() : this.error,
    viaYtDlp: viaYtDlp,
  );
}

/// What can be saved, and how (task 4.3).
enum DownloadKind {
  /// A plain media file over HTTP(S): downloaded with range requests.
  direct,

  /// A page or a streaming manifest: only with the yt-dlp plugin.
  ytDlp,

  /// Local files, other protocols, or nothing that can be fetched.
  none,
}

/// Downloads with a queue, pause/resume (HTTP range requests) and an
/// optional yt-dlp plugin for supported sites (task 4.3).
class DownloadManager extends Notifier<List<DownloadTask>> {
  /// Downloads at the same time.
  static const concurrency = 2;

  static const mediaExtensions = {
    '.mp4', '.m4v', '.mkv', '.webm', '.avi', '.mov', '.mp3', '.m4a', '.flac',
    '.ogg', '.opus', '.wav', '.ts', '.wmv', '.flv', //
  };

  int _nextId = 1;
  final _running = <int, _Job>{};

  /// Overridable for tests: the yt-dlp executable, or null if absent.
  @visibleForTesting
  Future<String?> Function() ytDlpLocator = _findYtDlp;

  @override
  List<DownloadTask> build() {
    ref.onDispose(() {
      for (final j in _running.values) {
        j.cancel();
      }
    });
    return const [];
  }

  /// How [url] could be downloaded, given whether yt-dlp is installed.
  static DownloadKind kindOf(String url, {required bool hasYtDlp}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return DownloadKind.none;
    }
    final ext = p.extension(uri.path).toLowerCase();
    if (mediaExtensions.contains(ext)) return DownloadKind.direct;
    return hasYtDlp ? DownloadKind.ytDlp : DownloadKind.none;
  }

  Future<bool> hasYtDlp() async => await ytDlpLocator() != null;

  /// Queues [url] into [folder]. Returns the task, or null if it can't be
  /// downloaded.
  Future<DownloadTask?> add(String url, String folder) async {
    final kind = kindOf(url, hasYtDlp: await hasYtDlp());
    if (kind == DownloadKind.none) return null;
    final name = _fileName(url);
    final task = DownloadTask(
      id: _nextId++,
      url: url,
      path: _unique(p.join(folder, name)),
      viaYtDlp: kind == DownloadKind.ytDlp,
    );
    state = [...state, task];
    _pump();
    return task;
  }

  void pause(int id) {
    _running.remove(id)?.cancel();
    _set(id, (t) => t.copyWith(status: DownloadStatus.paused));
    _pump();
  }

  void resume(int id) {
    _set(
      id,
      (t) => t.copyWith(status: DownloadStatus.queued, error: () => null),
    );
    _pump();
  }

  void cancel(int id) {
    _running.remove(id)?.cancel();
    final t = _find(id);
    if (t != null) {
      final part = File('${t.path}.part');
      if (part.existsSync()) part.deleteSync();
    }
    _set(id, (t) => t.copyWith(status: DownloadStatus.cancelled));
    _pump();
  }

  /// Removes finished, failed and cancelled entries from the list.
  void clearFinished() => state = [
    for (final t in state)
      if (t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.running ||
          t.status == DownloadStatus.paused)
        t,
  ];

  DownloadTask? _find(int id) => state.where((t) => t.id == id).firstOrNull;

  void _set(int id, DownloadTask Function(DownloadTask) f) => state = [
    for (final t in state)
      if (t.id == id) f(t) else t,
  ];

  void _pump() {
    for (final t in state) {
      if (_running.length >= concurrency) return;
      if (t.status == DownloadStatus.queued && !_running.containsKey(t.id)) {
        final job = t.viaYtDlp ? _YtDlpJob(this, t) : _HttpJob(this, t);
        _running[t.id] = job;
        _set(t.id, (x) => x.copyWith(status: DownloadStatus.running));
        unawaited(
          job.run().then((_) {
            _running.remove(t.id);
            _pump();
          }),
        );
      }
    }
  }

  void _progress(int id, int received, int? total) => _set(
    id,
    (t) => t.status == DownloadStatus.running
        ? t.copyWith(received: received, total: () => total ?? t.total)
        : t,
  );

  void _finish(int id, {String? error, String? path}) => _set(
    id,
    (t) => t.status == DownloadStatus.running
        ? t.copyWith(
            status: error == null ? DownloadStatus.done : DownloadStatus.failed,
            error: () => error,
            path: path,
          )
        : t,
  );

  static String _fileName(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    final name = last == null ? 'download' : Uri.decodeComponent(last);
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _unique(String path) {
    bool taken(String x) =>
        File(x).existsSync() || state.any((t) => t.path == x);
    if (!taken(path)) return path;
    final base = p.withoutExtension(path);
    final ext = p.extension(path);
    for (var i = 2; ; i++) {
      final candidate = '$base ($i)$ext';
      if (!taken(candidate)) return candidate;
    }
  }

  static Future<String?> _findYtDlp() async {
    try {
      final r = await Process.run('yt-dlp', ['--version']);
      return r.exitCode == 0 ? 'yt-dlp' : null;
    } on ProcessException {
      return null;
    }
  }
}

abstract class _Job {
  Future<void> run();
  void cancel();
}

/// Plain HTTP with `Range` resume into `<file>.part`.
class _HttpJob implements _Job {
  new(this.manager, this.task);

  final DownloadManager manager;
  final DownloadTask task;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  bool _cancelled = false;
  StreamSubscription<List<int>>? _sub;

  @override
  void cancel() {
    _cancelled = true;
    unawaited(_sub?.cancel());
    _client.close(force: true);
  }

  @override
  Future<void> run() async {
    final part = File('${task.path}.part');
    IOSink? sink;
    try {
      part.parent.createSync(recursive: true);
      var have = part.existsSync() ? part.lengthSync() : 0;
      final req = await _client.getUrl(Uri.parse(task.url));
      if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      final res = await req.close();
      if (res.statusCode == 416 && have > 0) {
        // Already complete.
        await res.drain<void>();
        part.renameSync(task.path);
        manager._finish(task.id);
        return;
      }
      if (res.statusCode != 200 && res.statusCode != 206) {
        await res.drain<void>();
        manager._finish(task.id, error: 'Server answered ${res.statusCode}.');
        return;
      }
      if (res.statusCode == 200 && have > 0) {
        // Server ignored the range: start over.
        have = 0;
      }
      final total = res.contentLength < 0 ? null : have + res.contentLength;
      sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
      var received = have;
      manager._progress(task.id, received, total);
      final done = Completer<void>();
      _sub = res.listen(
        (chunk) {
          sink!.add(chunk);
          received += chunk.length;
          manager._progress(task.id, received, total);
        },
        onDone: done.complete,
        onError: done.completeError,
        cancelOnError: true,
      );
      await done.future;
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled) return;
      if (total != null && received < total) {
        manager._finish(
          task.id,
          error: 'The connection dropped. Resume to continue.',
        );
        return;
      }
      part.renameSync(task.path);
      manager._finish(task.id);
    } on Object catch (e) {
      await sink?.close();
      if (_cancelled) return;
      manager._finish(task.id, error: 'Download failed: $e');
    } finally {
      _client.close();
    }
  }
}

/// The optional yt-dlp plugin: runs the CLI and parses its progress lines.
class _YtDlpJob implements _Job {
  new(this.manager, this.task);

  final DownloadManager manager;
  final DownloadTask task;
  Process? _process;
  bool _cancelled = false;

  static final _progress = RegExp(r'\[download\]\s+([\d.]+)%');
  static final _dest = RegExp(r'\[download\] Destination: (.+)$');
  static final _merged = RegExp(r'\[Merger\] Merging formats into "(.+)"$');

  @override
  void cancel() {
    _cancelled = true;
    _process?.kill();
  }

  @override
  Future<void> run() async {
    final exe = await manager.ytDlpLocator();
    if (exe == null) {
      manager._finish(task.id, error: 'yt-dlp is not installed.');
      return;
    }
    String? output;
    try {
      final dir = p.dirname(task.path);
      _process = await Process.start(exe, [
        '--newline', '--no-playlist', '--continue', //
        '-o', p.join(dir, '%(title)s.%(ext)s'),
        task.url,
      ]);
      final errors = StringBuffer();
      unawaited(_process!.stderr.transform(utf8.decoder).forEach(errors.write));
      await _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            final pr = _progress.firstMatch(line);
            if (pr != null) {
              final pct = double.parse(pr.group(1)!);
              manager._progress(task.id, (pct * 10).round(), 1000);
            }
            output =
                _merged.firstMatch(line)?.group(1) ??
                _dest.firstMatch(line)?.group(1) ??
                output;
          });
      final code = await _process!.exitCode;
      if (_cancelled) return;
      if (code != 0) {
        final msg = errors.toString().trim().split('\n').lastOrNull;
        manager._finish(task.id, error: msg ?? 'yt-dlp failed ($code).');
        return;
      }
      manager._finish(task.id, path: output);
    } on ProcessException catch (e) {
      manager._finish(task.id, error: 'yt-dlp failed: ${e.message}');
    }
  }
}

final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>(DownloadManager.new);
