import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// A Watch Together room server (task 9.11), speaking the protocol of
/// Harbor's relay (JSON messages with a `t` field over a WebSocket at
/// `/r/<CODE>`), reduced to what a player needs: who is in the room, the
/// host's playback state, the guests' play/pause/seek requests, chat and
/// a clock.
///
/// Kyndrel runs it itself to host a room on the local network; the same
/// rules run on Cloudflare (`packaging/together/worker.js`) for rooms over
/// the internet.
class TogetherServer {
  new _(this._http);

  /// Listens on every network address at [port] (0: any free port).
  static Future<TogetherServer> start({int port = 0}) async {
    final http = await HttpServer.bind(InternetAddress.anyIPv4, port);
    return TogetherServer._(http).._serve();
  }

  final HttpServer _http;
  final _rooms = <String, _Room>{};

  int get port => _http.port;

  static final roomPath = RegExp(r'^/r/([A-Z0-9]{4,8})$');

  void _serve() {
    _http.listen((req) async {
      if (req.uri.path == '/' || req.uri.path == '/health') {
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true, 'kyndrel': true}));
        await req.response.close();
        return;
      }
      final m = roomPath.firstMatch(req.uri.path);
      if (m == null || !WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(req);
      final code = m[1]!;
      _rooms
          .putIfAbsent(code, _Room.new)
          .add(socket, onEmpty: () => _rooms.remove(code));
    });
  }

  Future<void> close() async {
    for (final r in _rooms.values) {
      await r.closeAll();
    }
    _rooms.clear();
    await _http.close(force: true);
  }
}

/// A new room code: six letters and digits without look-alikes.
String newRoomCode({math.Random? random}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = random ?? math.Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < 6; i++) chars.codeUnitAt(r.nextInt(chars.length)),
  ]);
}

class _Peer {
  new(this.id, this.name);
  final String id;
  final String name;
  final int joinedAt = DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'joinedAt': joinedAt,
  };
}

class _Room {
  final _peers = <WebSocket, _Peer>{};
  Map<String, Object?>? _state;
  String? _host;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  void add(WebSocket socket, {required void Function() onEmpty}) {
    socket.listen(
      (data) {
        if (data is! String) return;
        try {
          final msg = jsonDecode(data);
          if (msg is Map<String, Object?>) _onMessage(socket, msg);
        } on FormatException {
          // Not ours.
        }
      },
      onDone: () {
        _leave(socket);
        if (_peers.isEmpty) onEmpty();
      },
      cancelOnError: true,
    );
  }

  void _send(WebSocket s, Map<String, Object?> msg) {
    try {
      s.add(jsonEncode(msg));
    } on Object {
      // Closing.
    }
  }

  void _broadcast(Map<String, Object?> msg, {WebSocket? except}) {
    final text = jsonEncode(msg);
    for (final s in _peers.keys) {
      if (s == except) continue;
      try {
        s.add(text);
      } on Object {
        // Closing.
      }
    }
  }

  void _onMessage(WebSocket socket, Map<String, Object?> msg) {
    switch (msg['t']) {
      case 'hello':
        final id = msg['clientId'];
        if (id is! String || id.isEmpty) return;
        final name = '${msg['name'] ?? 'Guest'}';
        final peer = _Peer(id, name.length > 32 ? name.substring(0, 32) : name);
        // The same person reconnecting replaces the old connection.
        for (final e in _peers.entries.toList()) {
          if (e.value.id == id && e.key != socket) {
            _peers.remove(e.key);
            unawaited(e.key.close());
          }
        }
        _peers[socket] = peer;
        final becameHost = _host == null;
        _host ??= id;
        _send(socket, {
          't': 'joined',
          'participants': [for (final p in _peers.values) p.toJson()],
          'state': _state,
          'hostClientId': _host,
          'srvAt': _now,
        });
        _broadcast({
          't': 'participant-joined',
          'participant': peer.toJson(),
        }, except: socket);
        if (becameHost) _broadcast({'t': 'host', 'hostClientId': _host});
      case 'state':
        final peer = _peers[socket];
        final s = msg['state'];
        // Only the host sets the room's playback.
        if (peer == null || peer.id != _host || s is! Map) return;
        final pos = s['positionSeconds'];
        if (pos is! num || pos < 0 || s['playing'] is! bool) return;
        _state = {...s.cast<String, Object?>(), 'srvAt': _now};
        _broadcast({
          't': 'state',
          'state': _state,
          'from': peer.id,
        }, except: socket);
      case 'cmd':
        final peer = _peers[socket];
        final c = msg['command'];
        if (peer == null || c is! Map || _host == null || peer.id == _host) {
          return;
        }
        final action = c['action'];
        if (action != 'play' && action != 'pause' && action != 'seek') return;
        if (action == 'seek' && c['positionSeconds'] is! num) return;
        for (final e in _peers.entries) {
          if (e.value.id == _host) {
            _send(e.key, {'t': 'cmd', 'from': peer.id, 'command': c});
          }
        }
      case 'chat':
        final peer = _peers[socket];
        final text = msg['text'];
        if (peer == null || text is! String || text.trim().isEmpty) return;
        _broadcast({
          't': 'chat',
          'from': peer.id,
          'name': peer.name,
          'text': text.length > 500 ? text.substring(0, 500) : text,
          'at': _now,
        });
      case 'ping':
        _send(socket, {'t': 'pong', 'srvAt': _now});
    }
  }

  void _leave(WebSocket socket) {
    final peer = _peers.remove(socket);
    if (peer == null) return;
    _broadcast({'t': 'participant-left', 'id': peer.id});
    if (peer.id == _host) {
      // The longest-present guest takes over.
      final next = _peers.values.toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      _host = next.isEmpty ? null : next.first.id;
      _broadcast({'t': 'host', 'hostClientId': _host});
    }
  }

  Future<void> closeAll() async {
    for (final s in _peers.keys.toList()) {
      await s.close();
    }
    _peers.clear();
  }
}
