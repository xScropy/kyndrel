import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/features/download/download_manager.dart';
import 'package:path/path.dart' as p;

/// Serves [data] with Range support; [slow] sends it in delayed chunks.
Future<HttpServer> _serve(Uint8List data, {bool slow = false}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final range = req.headers.value(HttpHeaders.rangeHeader);
    var start = 0;
    if (range != null) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      req.response.statusCode = HttpStatus.partialContent;
    }
    final body = data.sublist(start);
    req.response.contentLength = body.length;
    try {
      if (slow) {
        for (var i = 0; i < body.length; i += 1000) {
          req.response.add(body.sublist(i, (i + 1000).clamp(0, body.length)));
          await req.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      } else {
        req.response.add(body);
      }
      await req.response.close();
    } on Object {
      // Client went away (pause).
    }
  });
  return server;
}

void main() {
  late Directory dir;
  late ProviderContainer c;
  setUp(() {
    // The Flutter test binding fakes HttpClient (every request gets a 400);
    // these tests talk to a real local server.
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = saved);
    dir = Directory.systemTemp.createTempSync('kyndrel_dl');
    c = ProviderContainer()..listen(downloadManagerProvider, (_, _) {});
    c.read(downloadManagerProvider.notifier).ytDlpLocator = () async => null;
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  DownloadManager m() => c.read(downloadManagerProvider.notifier);
  DownloadTask task(int id) =>
      c.read(downloadManagerProvider).firstWhere((t) => t.id == id);

  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 400 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(check(), isTrue);
  }

  final data = Uint8List.fromList(List.generate(200000, (i) => i % 251));

  test('what can be downloaded', () {
    DownloadKind k(String u, {bool y = false}) =>
        DownloadManager.kindOf(u, hasYtDlp: y);
    expect(k('https://x.org/films/a.mp4?sig=1'), DownloadKind.direct);
    expect(k('http://x.org/a.MKV'), DownloadKind.direct);
    expect(k('https://x.org/live/index.m3u8'), DownloadKind.none);
    expect(k('https://x.org/live/index.m3u8', y: true), DownloadKind.ytDlp);
    expect(k('https://video.site/watch?v=1', y: true), DownloadKind.ytDlp);
    expect(k('/home/me/a.mp4'), DownloadKind.none);
    expect(k('rtsp://cam/stream', y: true), DownloadKind.none);
  });

  test('downloads a file over HTTP', () async {
    final server = await _serve(data);
    addTearDown(server.close);
    final t = await m().add(
      'http://127.0.0.1:${server.port}/media/Clip%20One.mp4',
      dir.path,
    );
    expect(t!.fileName, 'Clip One.mp4');
    await until(() => task(t.id).status == DownloadStatus.done);
    expect(File(p.join(dir.path, 'Clip One.mp4')).readAsBytesSync(), data);
    expect(task(t.id).progress, 1);
  });

  test('pause and resume continue with a Range request', () async {
    final server = await _serve(data, slow: true);
    addTearDown(server.close);
    final t = await m().add('http://127.0.0.1:${server.port}/a.mp4', dir.path);
    await until(() => task(t!.id).received > 20000);
    m().pause(t!.id);
    expect(task(t.id).status, DownloadStatus.paused);
    final partial = File('${t.path}.part').lengthSync();
    expect(partial, greaterThan(0));
    expect(partial, lessThan(data.length));

    m().resume(t.id);
    await until(() => task(t.id).status == DownloadStatus.done);
    expect(File(t.path).readAsBytesSync(), data);
  });

  test('cancel removes the partial file; names never collide', () async {
    final server = await _serve(data, slow: true);
    addTearDown(server.close);
    final a = await m().add('http://127.0.0.1:${server.port}/a.mp4', dir.path);
    final b = await m().add('http://127.0.0.1:${server.port}/a.mp4', dir.path);
    expect(b!.fileName, 'a (2).mp4');
    await until(() => task(a!.id).received > 0);
    m().cancel(a!.id);
    expect(task(a.id).status, DownloadStatus.cancelled);
    expect(File('${a.path}.part').existsSync(), isFalse);
  });

  test('HTTP errors are reported', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((r) async {
      r.response.statusCode = 404;
      await r.response.close();
    });
    final t = await m().add('http://127.0.0.1:${server.port}/x.mp4', dir.path);
    await until(() => task(t!.id).status == DownloadStatus.failed);
    expect(task(t!.id).error, contains('404'));
  });

  test('yt-dlp plugin: progress and final file from its output', () async {
    final script = File(p.join(dir.path, 'yt-dlp'))
      ..writeAsStringSync(
        '#!/bin/sh\n'
        '''
echo "[download] Destination: ${dir.path}/Video Title.mp4"
echo "[download]  42.0% of 10.00MiB"
echo "[download] 100.0% of 10.00MiB"
touch "${dir.path}/Video Title.mp4"
''',
      );
    await Process.run('chmod', ['+x', script.path]);
    m().ytDlpLocator = () async => script.path;
    final t = await m().add('https://video.site/watch?v=1', dir.path);
    expect(t!.viaYtDlp, isTrue);
    await until(() => task(t.id).status == DownloadStatus.done);
    expect(task(t.id).path, '${dir.path}/Video Title.mp4');
  }, skip: Platform.isWindows);

  test('local files and unknown pages without yt-dlp are refused', () async {
    expect(await m().add('/home/me/a.mp4', dir.path), isNull);
    expect(await m().add('https://video.site/watch?v=1', dir.path), isNull);
  });
}
