import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/features/network/open_url_dialog.dart';
import 'package:kyndrel/features/network/webdav.dart';

import '../../support/fake_player_backend.dart';

const _multistatus = '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/Films/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response><d:href>/dav/Films/Season%201/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response><d:href>/dav/Films/The%20Film.mkv</d:href>
    <d:propstat><d:prop><d:resourcetype/><d:getcontentlength>1234</d:getcontentlength></d:prop></d:propstat>
  </d:response>
  <d:response><d:href>/dav/Films/a.mp4</d:href>
    <d:propstat><d:prop><d:displayname>Another</d:displayname><d:resourcetype/></d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

void main() {
  test('PROPFIND reply: folders first, the folder itself left out', () {
    final e = parseMultistatus(
      Uri.parse('https://nas.local/dav/Films/'),
      _multistatus,
    );
    expect(e.map((x) => x.name), ['Season 1', 'Another', 'The Film.mkv']);
    expect(e.first.isFolder, isTrue);
    expect(e.last.size, 1234);
    expect(e.last.url.toString(), 'https://nas.local/dav/Films/The%20Film.mkv');
  });

  test('basic auth header', () {
    expect(
      basicAuthHeader('me', 'pa:ss'),
      'Authorization: Basic ${base64.encode(utf8.encode('me:pa:ss'))}',
    );
  });

  test('WebDAV client sends PROPFIND with Depth 1 and login', () async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = saved);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      expect(req.method, 'PROPFIND');
      expect(req.headers.value('Depth'), '1');
      if (req.headers.value('Authorization') == null) {
        req.response.statusCode = 401;
      } else {
        req.response
          ..statusCode = 207
          ..write(_multistatus);
      }
      await req.response.close();
    });
    final url = Uri.parse('http://127.0.0.1:${server.port}/dav/Films/');
    await expectLater(
      WebDavClient().list(url),
      throwsA(isA<WebDavException>()),
    );
    final entries = await WebDavClient(user: 'me', password: 'x').list(url);
    expect(entries, hasLength(3));
  });

  test('URL validation', () {
    for (final ok in [
      'https://x.org/a.m3u8',
      'rtsp://cam.local:554/stream',
      'smb://nas/share/a.mkv',
      'http://10.0.0.2:8080/dash/manifest.mpd',
    ]) {
      expect(OpenUrlDialogState.isValid(ok), isTrue, reason: ok);
    }
    for (final bad in ['x.org/a.mp4', 'file:///a.mp4', 'https://']) {
      expect(OpenUrlDialogState.isValid(bad), isFalse, reason: bad);
    }
  });

  test('per-source HTTP headers are set before opening', () async {
    final backend = FakePlayerBackend();
    final service = PlayerService(backend)
      ..setSourceHeaders('https://nas/a.mkv', ['Authorization: Basic eA==']);
    addTearDown(service.dispose);
    await service.open('https://nas/a.mkv');
    expect(
      backend.properties['http-header-fields'],
      'Authorization: Basic eA==',
    );
    await service.open('https://other/b.mkv');
    expect(backend.properties['http-header-fields'], '');
  });
}
