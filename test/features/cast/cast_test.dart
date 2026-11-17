// Payloads are inspected as decoded JSON.
// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/remote_target.dart';
import 'package:kyndrel/features/cast/cast_controller.dart';
import 'package:kyndrel/features/cast/cast_device.dart';
import 'package:kyndrel/features/cast/cast_server.dart';
import 'package:kyndrel/features/cast/cast_session.dart';
import 'package:kyndrel/features/cast/castv2.dart';
import 'package:kyndrel/features/cast/chromecast_discovery.dart';
import 'package:kyndrel/features/cast/dlna.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_player_backend.dart';

void main() {
  setUp(() {
    // Real sockets: undo the Flutter test binding's fake HttpClient.
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = saved);
  });

  group('CastV2 framing', () {
    test('encode/decode round trip, split across chunks', () async {
      const m = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: ChromecastSession.nsReceiver,
        payload: '{"type":"LAUNCH","appId":"CC1AD845","requestId":1}',
      );
      final bytes = [...m.encode(), ...m.encode()];
      final chunks = [
        bytes.sublist(0, 3),
        bytes.sublist(3, 40),
        bytes.sublist(40),
      ];
      final out = await Stream.fromIterable(chunks)
          .transform(const CastFrameDecoder())
          .toList();
      expect(out, hasLength(2));
      expect(out[1].namespace, ChromecastSession.nsReceiver);
      expect(out[1].json['appId'], 'CC1AD845');
      expect(out[0].destinationId, 'receiver-0');
    });
  });

  test('Chromecast session against a fake receiver', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = <Map<String, Object?>>[];
    server.listen((socket) {
      void reply(String ns, Map<String, Object?> payload, String src) =>
          socket.add(
            CastMessage(
              sourceId: src,
              destinationId: ChromecastSession.sender,
              namespace: ns,
              payload: jsonEncode(payload),
            ).encode(),
          );
      socket.cast<List<int>>().transform(const CastFrameDecoder()).listen((m) {
        final j = m.json
          ..['_ns'] = m.namespace
          ..['_dest'] = m.destinationId;
        received.add(j);
        final id = j['requestId'];
        switch (j['type']) {
          case 'LAUNCH':
            reply(ChromecastSession.nsReceiver, {
              'type': 'RECEIVER_STATUS',
              'requestId': id,
              'status': {
                'applications': [
                  {'appId': 'CC1AD845', 'transportId': 'web-5'},
                ],
              },
            }, 'receiver-0');
          case 'LOAD' || 'GET_STATUS':
            reply(ChromecastSession.nsMedia, {
              'type': 'MEDIA_STATUS',
              'requestId': id,
              'status': [
                {
                  'mediaSessionId': 7,
                  'playerState': 'PLAYING',
                  'currentTime': 42.5,
                  'media': {'duration': 600},
                },
              ],
            }, 'web-5');
        }
      });
    });

    final session = await ChromecastSession.connect(
      'Living Room',
      '127.0.0.1',
      server.port,
      socketFactory: Socket.connect,
    );
    final statuses = <RemoteStatus>[];
    session.status.listen(statuses.add);
    await session.load(
      Uri.parse('http://192.168.1.2:8000/x/media.mp4'),
      contentType: 'video/mp4',
      title: 'Film',
      startAt: const Duration(seconds: 30),
      subtitleUrl: Uri.parse('http://192.168.1.2:8000/x/subs.vtt'),
    );
    await session.play();
    await session.pause();
    await session.seek(const Duration(seconds: 90));
    await session.setVolume(0.5);
    await Future<void>.delayed(const Duration(milliseconds: 1300));

    String? type(Map<String, Object?> j) => j['type'] as String?;
    final load = received.firstWhere((j) => type(j) == 'LOAD');
    expect(load['_dest'], 'web-5');
    expect(load['currentTime'], 30);
    final media = load['media']! as Map;
    expect(media['contentId'], 'http://192.168.1.2:8000/x/media.mp4');
    expect((media['tracks']! as List).single['trackContentType'], 'text/vtt');
    expect(
      received.where((j) => j['mediaSessionId'] == 7).map(type),
      containsAllInOrder(['PLAY', 'PAUSE', 'SEEK']),
    );
    expect(received.firstWhere((j) => type(j) == 'SEEK')['currentTime'], 90);
    expect(
      (received.firstWhere((j) => type(j) == 'SET_VOLUME')['volume']!
          as Map)['level'],
      0.5,
    );
    expect(received.any((j) => type(j) == 'GET_STATUS'), isTrue);
    expect(statuses.last.position, const Duration(milliseconds: 42500));
    expect(statuses.last.duration, const Duration(minutes: 10));
    expect(statuses.last.playing, isTrue);
    await session.stop();
  });

  group('DLNA', () {
    test('SSDP replies and device descriptions', () {
      final loc = parseSsdpReply(
        'HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\n'
        'LOCATION: http://192.168.1.50:9197/dmr\r\n'
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n',
      );
      expect(loc, Uri.parse('http://192.168.1.50:9197/dmr'));
      expect(
        parseSsdpReply(
          'HTTP/1.1 200 OK\r\nST: upnp:rootdevice\r\n'
          'LOCATION: http://x/\r\n\r\n',
        ),
        isNull,
      );
      final d = parseDeviceDescription(loc!, _description);
      expect(d!.name, 'Bedroom TV');
      expect(d.kind, CastKind.dlna);
      expect(
        d.avTransportUrl.toString(),
        'http://192.168.1.50:9197/upnp/control/AVTransport1',
      );
      expect(d.renderingControlUrl!.path, '/upnp/control/RenderingControl1');
    });

    test('time format', () {
      expect(
        upnpTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(
        parseUpnpTime('00:10:05.000'),
        const Duration(minutes: 10, seconds: 5),
      );
      expect(parseUpnpTime('NOT_IMPLEMENTED'), isNull);
    });

    test('session sends AVTransport actions and polls position', () async {
      final actions = <String>[];
      final bodies = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((req) async {
        final action = req.headers
            .value('SOAPAction')!
            .split('#')
            .last
            .replaceAll('"', '');
        actions.add(action);
        bodies.add(await utf8.decodeStream(req));
        req.response.write(switch (action) {
          'GetPositionInfo' =>
            '<s:Envelope><s:Body><u:R><RelTime>00:01:30</RelTime>'
                '<TrackDuration>00:45:00</TrackDuration></u:R></s:Body></s:Envelope>',
          'GetTransportInfo' =>
            '<s:Envelope><s:Body><u:R><CurrentTransportState>PLAYING'
                '</CurrentTransportState></u:R></s:Body></s:Envelope>',
          _ => '<s:Envelope><s:Body/></s:Envelope>',
        });
        await req.response.close();
      });
      final base = 'http://127.0.0.1:${server.port}';
      final s = DlnaSession(
        CastDevice(
          id: 'dlna:1',
          name: 'TV',
          kind: CastKind.dlna,
          host: '127.0.0.1',
          port: server.port,
          avTransportUrl: Uri.parse('$base/av'),
          renderingControlUrl: Uri.parse('$base/rc'),
        ),
      );
      final statuses = <RemoteStatus>[];
      s.status.listen(statuses.add);
      await s.load(
        Uri.parse('http://192.168.1.2:8000/x/media.mkv'),
        contentType: 'video/x-matroska',
        title: 'Film & Co',
      );
      await s.pause();
      await s.seek(const Duration(minutes: 5));
      await s.setVolume(0.3);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(actions.take(5), [
        'SetAVTransportURI', 'Play', 'Pause', 'Seek', 'SetVolume', //
      ]);
      expect(bodies[0], contains('Film &amp;amp; Co'));
      expect(bodies[3], contains('<Target>00:05:00</Target>'));
      expect(bodies[4], contains('<DesiredVolume>30</DesiredVolume>'));
      expect(statuses.last.position, const Duration(minutes: 1, seconds: 30));
      expect(statuses.last.duration, const Duration(minutes: 45));
      await s.stop();
      expect(actions.last, 'Stop');
    });
  });

  test('Chromecast TXT friendly name', () {
    expect(
      friendlyNameFromTxt('id=abc\nfn=Living Room\nmd=Chromecast'),
      'Living Room',
    );
  });

  group('media server', () {
    late Directory dir;
    late CastServer server;
    final data = Uint8List.fromList(List.generate(5000, (i) => i % 256));
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('kyndrel_cast');
      File(p.join(dir.path, 'film.mp4')).writeAsBytesSync(data);
      server = await CastServer.start(host: '127.0.0.1');
    });
    tearDown(() async {
      await server.close();
      dir.deleteSync(recursive: true);
    });

    test('serves the file with ranges and CORS, subtitles as VTT', () async {
      final url = server.serve(p.join(dir.path, 'film.mp4'), vtt: 'WEBVTT\n');
      final full = await http.get(url);
      expect(full.bodyBytes, data);
      expect(full.headers['content-type'], 'video/mp4');
      expect(full.headers['access-control-allow-origin'], '*');
      expect(full.headers['accept-ranges'], 'bytes');
      final part = await http.get(url, headers: {'Range': 'bytes=100-199'});
      expect(part.statusCode, 206);
      expect(part.bodyBytes, data.sublist(100, 200));
      expect(part.headers['content-range'], 'bytes 100-199/5000');
      final tail = await http.get(url, headers: {'Range': 'bytes=4900-'});
      expect(tail.bodyBytes, data.sublist(4900));
      final vtt = await http.get(server.subtitleUrl!);
      expect(vtt.headers['content-type'], startsWith('text/vtt'));
      final wrong = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/nope/media.mp4'),
      );
      expect(wrong.statusCode, 404);
    });
  });

  test('codec support for Chromecast', () {
    bool can(String? v, String? a, String path) =>
        chromecastCanPlay(videoCodec: v, audioCodec: a, path: path);
    expect(can('h264', 'aac', 'a.mp4'), isTrue);
    expect(can('vp9', 'opus', 'a.webm'), isTrue);
    expect(can('hevc', 'aac', 'a.mkv'), isFalse);
    expect(can('h264', 'ac3', 'a.mkv'), isFalse);
    expect(can('h264', 'aac', 'a.avi'), isFalse);
  });

  group('PlayerService with a remote target', () {
    test('commands go to the device and state follows it', () async {
      final backend = FakePlayerBackend();
      final service = PlayerService(backend);
      addTearDown(service.dispose);
      await service.open('/v/a.mkv');
      backend.emitDuration(const Duration(minutes: 10));
      final remote = _FakeRemote();
      await service.attachRemote(remote);
      expect(backend.calls.last, 'pause');
      await service.play();
      await service.seek(const Duration(minutes: 2));
      await service.setVolume(150);
      expect(remote.calls, ['play', 'seek(120)', 'volume(1.0)']);
      remote.emit(
        const RemoteStatus(position: Duration(minutes: 3), playing: true),
      );
      await pumpEventQueue();
      expect(service.state.position, const Duration(minutes: 3));
      expect(service.state.isPlaying, isTrue);
      await service.detachRemote();
      expect(remote.calls.last, 'stop');
      expect(backend.calls.last, 'seek(180000)', reason: 'local resumes there');
      backend.calls.clear();
      await service.play();
      expect(backend.calls, ['play']);
    });
  });

  group('controller', () {
    late Directory dir;
    late FakePlayerBackend backend;
    late PlayerService service;
    late _FakePlatform platform;
    late ProviderContainer c;
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('kyndrel_castc');
      File(p.join(dir.path, 'film.mkv')).writeAsBytesSync([1, 2, 3]);
      backend = FakePlayerBackend();
      service = PlayerService(backend);
      platform = _FakePlatform();
      c = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(service),
          castPlatformProvider.overrideWithValue(platform),
        ],
      )..listen(castProvider, (_, _) {});
      await service.open(p.join(dir.path, 'film.mkv'));
      backend
        ..emitDuration(const Duration(minutes: 10))
        ..emitPosition(const Duration(minutes: 1));
    });
    tearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });

    void tracks(String video, String audio) {
      backend.emitTracks([
        {'id': '1', 'type': 'video', 'codec': video},
        {'id': '1', 'type': 'audio', 'codec': audio},
      ]);
    }

    test('scan lists devices', () async {
      await c.read(castProvider.notifier).scan();
      expect(c.read(castProvider).devices, [_FakePlatform.tv]);
    });

    test('supported file is served as is from the current position', () async {
      tracks('h264', 'aac');
      await pumpEventQueue();
      await c.read(castProvider.notifier).castTo(_FakePlatform.tv);
      expect(c.read(castProvider).active, _FakePlatform.tv);
      expect(c.read(castProvider).transcoding, isFalse);
      final m = platform.session.loaded.single;
      expect(m.url.path, endsWith('/media.mkv'));
      expect(m.startAt, const Duration(minutes: 1));
      expect(service.remote, isNotNull);
      await c.read(castProvider.notifier).stop();
      expect(service.remote, isNull);
      expect(c.read(castProvider).active, isNull);
    });

    test('HEVC is transcoded; seeking restarts the transcode', () async {
      tracks('hevc', 'aac');
      await pumpEventQueue();
      await c.read(castProvider.notifier).castTo(_FakePlatform.tv);
      expect(c.read(castProvider).transcoding, isTrue);
      expect(
        platform.session.loaded.single.url.path,
        endsWith('transcode.mp4'),
      );
      expect(platform.session.loaded.single.url.queryParameters['t'], '60');
      await service.seek(const Duration(minutes: 4));
      expect(platform.session.loaded.last.url.queryParameters['t'], '240');
      platform.session.emit(
        const RemoteStatus(position: Duration(seconds: 5), playing: true),
      );
      await pumpEventQueue();
      expect(service.state.position, const Duration(minutes: 4, seconds: 5));
    });

    test('connection errors are reported', () async {
      platform.fail = true;
      await c.read(castProvider.notifier).castTo(_FakePlatform.tv);
      expect(c.read(castProvider).active, isNull);
      expect(c.read(castProvider).error, contains("Couldn't cast"));
    });
  });
}

class _FakeRemote implements CastSession {
  final calls = <String>[];
  final loaded = <CastMedia>[];
  final _status = StreamController<RemoteStatus>.broadcast(sync: true);
  void emit(RemoteStatus s) => _status.add(s);

  @override
  String get name => 'Fake TV';
  @override
  Stream<RemoteStatus> get status => _status.stream;
  @override
  Future<void> loadMedia(CastMedia media) async => loaded.add(media);
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration p) async => calls.add('seek(${p.inSeconds})');
  @override
  Future<void> setVolume(double v) async => calls.add('volume($v)');
  @override
  Future<void> stop() async => calls.add('stop');
}

class _FakePlatform implements CastPlatform {
  static const tv = CastDevice(
    id: 'cc:tv',
    name: 'Living Room',
    kind: CastKind.chromecast,
    host: '10.0.0.5',
    port: 8009,
  );
  final session = _FakeRemote();
  bool fail = false;

  @override
  Future<List<CastDevice>> discover() async => [tv];
  @override
  Future<CastSession> connect(CastDevice d) async {
    if (fail) throw const SocketException('unreachable');
    return session;
  }

  @override
  Future<CastServer> startServer() => CastServer.start(host: '127.0.0.1');
  @override
  Future<bool> canTranscode() async => true;
}

const _description = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Bedroom TV</friendlyName>
    <UDN>uuid:1234</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/RenderingControl1</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/AVTransport1</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';
