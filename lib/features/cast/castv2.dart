import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kyndrel/core/player/remote_target.dart';
import 'package:kyndrel/features/cast/cast_session.dart';

/// One CastV2 message (the `CastMessage` protobuf, string payloads only).
class CastMessage {
  const new({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payload,
  });

  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payload;

  Map<String, Object?> get json =>
      (jsonDecode(payload) as Map).cast<String, Object?>();

  /// Protobuf encoding with the 4-byte big-endian length prefix.
  Uint8List encode() {
    final b = BytesBuilder();
    void varint(int v) {
      var x = v;
      while (x >= 0x80) {
        b.addByte((x & 0x7F) | 0x80);
        x >>= 7;
      }
      b.addByte(x);
    }

    void str(int field, String s) {
      final bytes = utf8.encode(s);
      varint((field << 3) | 2);
      varint(bytes.length);
      b.add(bytes);
    }

    varint(1 << 3); // protocol_version = CASTV2_1_0 (0)
    varint(0);
    str(2, sourceId);
    str(3, destinationId);
    str(4, namespace);
    varint(5 << 3); // payload_type = STRING (0)
    varint(0);
    str(6, payload);
    final body = b.takeBytes();
    return Uint8List(4 + body.length)
      ..buffer.asByteData().setUint32(0, body.length)
      ..setRange(4, 4 + body.length, body);
  }

  /// Decodes one message body (without the length prefix).
  // ignore: prefer_constructors_over_static_methods, a parser, not a builder
  static CastMessage decode(Uint8List body) {
    var i = 0;
    int varint() {
      var result = 0;
      var shift = 0;
      while (true) {
        final byte = body[i++];
        result |= (byte & 0x7F) << shift;
        if (byte < 0x80) return result;
        shift += 7;
      }
    }

    final fields = <int, String>{};
    while (i < body.length) {
      final key = varint();
      final field = key >> 3;
      final type = key & 7;
      if (type == 0) {
        varint();
      } else if (type == 2) {
        final len = varint();
        fields[field] = utf8.decode(body.sublist(i, i + len));
        i += len;
      } else {
        throw const FormatException('Unsupported protobuf wire type');
      }
    }
    return CastMessage(
      sourceId: fields[2] ?? '',
      destinationId: fields[3] ?? '',
      namespace: fields[4] ?? '',
      payload: fields[6] ?? '{}',
    );
  }
}

/// Splits a byte stream into length-prefixed CastV2 messages.
class CastFrameDecoder extends StreamTransformerBase<List<int>, CastMessage> {
  const new();

  @override
  Stream<CastMessage> bind(Stream<List<int>> stream) async* {
    var buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      buffer.add(chunk);
      var bytes = buffer.toBytes();
      var offset = 0;
      while (bytes.length - offset >= 4) {
        final len = ByteData.sublistView(
          bytes,
          offset,
          offset + 4,
        ).getUint32(0);
        if (bytes.length - offset - 4 < len) break;
        yield CastMessage.decode(
          Uint8List.sublistView(bytes, offset + 4, offset + 4 + len),
        );
        offset += 4 + len;
      }
      buffer = BytesBuilder(copy: false)..add(bytes.sublist(offset));
      bytes = Uint8List(0);
    }
  }
}

typedef CastSocketFactory = Future<Socket> Function(String host, int port);

/// Connects with TLS; Chromecasts use self-signed certificates.
Future<Socket> secureCastSocket(String host, int port) => SecureSocket.connect(
  host,
  port,
  onBadCertificate: (_) => true,
  timeout: const Duration(seconds: 8),
);

class CastException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Plays media on a Chromecast with the Default Media Receiver (task 4.4).
class ChromecastSession implements CastSession {
  new _(this.name, this._socket);

  static const defaultMediaReceiver = 'CC1AD845';
  static const nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const nsMedia = 'urn:x-cast:com.google.cast.media';
  static const sender = 'sender-kyndrel';

  static Future<ChromecastSession> connect(
    String name,
    String host,
    int port, {
    CastSocketFactory socketFactory = secureCastSocket,
  }) async {
    return ChromecastSession._(name, await socketFactory(host, port)).._start();
  }

  @override
  final String name;
  final Socket _socket;
  final _messages = StreamController<CastMessage>.broadcast();
  final _status = StreamController<RemoteStatus>.broadcast();
  Timer? _heartbeat;
  Timer? _poll;
  int _requestId = 1;
  String? _transportId;
  int? _mediaSessionId;
  Duration? _duration;

  @override
  Stream<RemoteStatus> get status => _status.stream;

  void _start() {
    _socket
        .cast<List<int>>()
        .transform(const CastFrameDecoder())
        .listen(_onMessage, onError: (Object _) => _close(), onDone: _close);
    _send('receiver-0', nsConnection, {'type': 'CONNECT'});
    _heartbeat = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _send('receiver-0', nsHeartbeat, {'type': 'PING'}),
    );
  }

  void _onMessage(CastMessage m) {
    final j = m.json;
    if (m.namespace == nsHeartbeat && j['type'] == 'PING') {
      _send(m.sourceId, nsHeartbeat, {'type': 'PONG'});
    }
    if (m.namespace == nsMedia && j['type'] == 'MEDIA_STATUS') {
      final list = (j['status'] as List?) ?? const [];
      if (list.isNotEmpty) {
        final st = (list.first as Map).cast<String, Object?>();
        _mediaSessionId =
            (st['mediaSessionId'] as num?)?.toInt() ?? _mediaSessionId;
        final media = (st['media'] as Map?)?.cast<String, Object?>();
        final d = (media?['duration'] as num?)?.toDouble();
        if (d != null) _duration = Duration(milliseconds: (d * 1000).round());
        final state = st['playerState'] as String?;
        _status.add(
          RemoteStatus(
            position: Duration(
              milliseconds: (((st['currentTime'] as num?) ?? 0) * 1000).round(),
            ),
            playing: state == 'PLAYING' || state == 'BUFFERING',
            duration: _duration,
            finished: state == 'IDLE' && st['idleReason'] == 'FINISHED',
          ),
        );
      }
    }
    if (!_messages.isClosed) _messages.add(m);
  }

  int _send(String dest, String ns, Map<String, Object?> payload) {
    final id = _requestId++;
    final data = {...payload, 'requestId': id};
    _socket.add(
      CastMessage(
        sourceId: sender,
        destinationId: dest,
        namespace: ns,
        payload: jsonEncode(data),
      ).encode(),
    );
    return id;
  }

  Future<Map<String, Object?>> _request(
    String dest,
    String ns,
    Map<String, Object?> payload,
    bool Function(Map<String, Object?>) accept,
  ) async {
    final reply = _messages.stream
        .where((m) => m.namespace == ns || m.namespace == nsReceiver)
        .map((m) => m.json)
        .firstWhere(accept)
        .timeout(const Duration(seconds: 15));
    _send(dest, ns, payload);
    return await reply;
  }

  /// Launches the receiver and loads [url]. [subtitleUrl] is WebVTT.
  Future<void> load(
    Uri url, {
    required String contentType,
    required String title,
    Duration startAt = Duration.zero,
    Uri? subtitleUrl,
  }) async {
    final status = await _request('receiver-0', nsReceiver, {
      'type': 'LAUNCH',
      'appId': defaultMediaReceiver,
    }, (j) => j['type'] == 'RECEIVER_STATUS' && _appTransport(j) != null);
    _transportId = _appTransport(status);
    _send(_transportId!, nsConnection, {'type': 'CONNECT'});
    final media = await _request(
      _transportId!,
      nsMedia,
      {
        'type': 'LOAD',
        'autoplay': true,
        'currentTime': startAt.inMilliseconds / 1000,
        'media': {
          'contentId': url.toString(),
          'contentType': contentType,
          'streamType': 'BUFFERED',
          'metadata': {'metadataType': 0, 'title': title},
          if (subtitleUrl != null)
            'tracks': [
              {
                'trackId': 1,
                'type': 'TEXT',
                'subtype': 'SUBTITLES',
                'trackContentId': subtitleUrl.toString(),
                'trackContentType': 'text/vtt',
                'language': 'und',
              },
            ],
        },
        if (subtitleUrl != null) 'activeTrackIds': [1],
      },
      (j) =>
          j['type'] == 'MEDIA_STATUS' ||
          j['type'] == 'LOAD_FAILED' ||
          j['type'] == 'INVALID_REQUEST',
    );
    if (media['type'] != 'MEDIA_STATUS') {
      throw CastException('The TV refused the video (${media['type']}).');
    }
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_transportId != null) {
        _send(_transportId!, nsMedia, {'type': 'GET_STATUS'});
      }
    });
  }

  static String? _appTransport(Map<String, Object?> j) {
    final apps = ((j['status'] as Map?)?['applications'] as List?) ?? const [];
    for (final a in apps.cast<Map<String, Object?>>()) {
      if (a['appId'] == defaultMediaReceiver) {
        return a['transportId'] as String?;
      }
    }
    return null;
  }

  void _media(String type, [Map<String, Object?> extra = const {}]) {
    final t = _transportId;
    final s = _mediaSessionId;
    if (t == null || s == null) return;
    _send(t, nsMedia, {'type': type, 'mediaSessionId': s, ...extra});
  }

  @override
  Future<void> loadMedia(CastMedia m) => load(
    m.url,
    contentType: m.contentType,
    title: m.title,
    startAt: m.startAt,
    subtitleUrl: m.subtitleUrl,
  );

  @override
  Future<void> play() async => _media('PLAY');

  @override
  Future<void> pause() async => _media('PAUSE');

  @override
  Future<void> seek(Duration position) async =>
      _media('SEEK', {'currentTime': position.inMilliseconds / 1000});

  @override
  Future<void> setVolume(double volume) async =>
      _send('receiver-0', nsReceiver, {
        'type': 'SET_VOLUME',
        'volume': {'level': volume.clamp(0, 1)},
      });

  @override
  Future<void> stop() async {
    _media('STOP');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _close();
  }

  void _close() {
    _heartbeat?.cancel();
    _poll?.cancel();
    _socket.destroy();
    if (!_messages.isClosed) unawaited(_messages.close());
    if (!_status.isClosed) unawaited(_status.close());
  }
}
