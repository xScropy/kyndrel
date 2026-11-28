import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Someone in a Watch Together room.
@immutable
class TogetherPeer {
  const new(this.id, this.name);
  final String id;
  final String name;
}

/// The host's playback, as the room last heard it.
@immutable
class TogetherState {
  const new({
    required this.position,
    required this.playing,
    this.speed = 1,
    this.title,
    this.serverAt,
  });

  factory fromJson(Map<String, Object?> j) => TogetherState(
    position: Duration(
      milliseconds: ((j['positionSeconds'] as num? ?? 0) * 1000).round(),
    ),
    playing: j['playing'] == true,
    speed: (j['speed'] as num?)?.toDouble() ?? 1,
    title: j['mediaTitle'] as String?,
    serverAt: (j['srvAt'] as num?)?.toInt(),
  );

  final Duration position;
  final bool playing;
  final double speed;

  /// The file's name, so guests can tell they opened the same one.
  final String? title;

  /// Server time (ms) when the server passed it on.
  final int? serverAt;

  Map<String, Object?> toJson() => {
    'positionSeconds': position.inMilliseconds / 1000,
    'playing': playing,
    'speed': speed,
    'mediaTitle': ?title,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };
}

/// What happens in a room.
sealed class TogetherEvent {
  const new();
}

class TogetherJoined extends TogetherEvent {
  const new(this.peers, this.hostId, this.state);
  final List<TogetherPeer> peers;
  final String? hostId;
  final TogetherState? state;
}

class TogetherPeerJoined extends TogetherEvent {
  const new(this.peer);
  final TogetherPeer peer;
}

class TogetherPeerLeft extends TogetherEvent {
  const new(this.id);
  final String id;
}

class TogetherHostChanged extends TogetherEvent {
  const new(this.hostId);
  final String? hostId;
}

class TogetherStateEvent extends TogetherEvent {
  const new(this.state);
  final TogetherState state;
}

/// A guest asks the host to play, pause or seek.
class TogetherCommand extends TogetherEvent {
  const new(this.action, {this.position});
  final String action;
  final Duration? position;
}

class TogetherChat extends TogetherEvent {
  const new(this.name, this.text);
  final String name;
  final String text;
}

class TogetherClosed extends TogetherEvent {
  const new();
}

/// A connection to a Watch Together room (task 9.11): the server is the
/// room server's address (`ws://192.168.1.5:7637` for one a Kyndrel hosts
/// on the local network, `wss://…workers.dev` for a Cloudflare relay).
class TogetherClient {
  new _(this._socket, this.clientId);

  static Future<TogetherClient> connect({
    required Uri server,
    required String room,
    required String clientId,
    required String name,
  }) async {
    final url = server.replace(
      path: '${server.path.replaceAll(RegExp(r'/$'), '')}/r/$room',
    );
    final socket = await WebSocket.connect('$url')
        .timeout(const Duration(seconds: 10));
    return TogetherClient._(socket, clientId)
      .._listen()
      .._send({'t': 'hello', 'clientId': clientId, 'name': name})
      .._ping();
  }

  final WebSocket _socket;
  final String clientId;
  final _events = StreamController<TogetherEvent>.broadcast();
  Timer? _pinger;
  int? _pingSentAt;

  /// Server clock minus ours, in ms, from the last ping (half the round
  /// trip assumed each way).
  int clockOffset = 0;

  Stream<TogetherEvent> get events => _events.stream;

  /// The server's time now, in ms.
  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockOffset;

  void _listen() {
    _socket.listen(
      (data) {
        if (data is! String) return;
        try {
          final msg = jsonDecode(data);
          if (msg is Map<String, Object?>) _onMessage(msg);
        } on FormatException {
          // Not ours.
        }
      },
      onDone: _closed,
      onError: (Object _) => _closed(),
      cancelOnError: true,
    );
    _pinger = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
  }

  static TogetherPeer _peer(Object? j) {
    final m = j is Map ? j : const <String, Object?>{};
    return TogetherPeer('${m['id']}', '${m['name'] ?? 'Guest'}');
  }

  void _onMessage(Map<String, Object?> m) {
    final e = switch (m['t']) {
      'joined' => TogetherJoined(
        [for (final p in (m['participants'] as List? ?? const [])) _peer(p)],
        m['hostClientId'] as String?,
        m['state'] is Map
            ? TogetherState.fromJson((m['state']! as Map).cast())
            : null,
      ),
      'participant-joined' => TogetherPeerJoined(_peer(m['participant'])),
      'participant-left' => TogetherPeerLeft('${m['id']}'),
      'host' => TogetherHostChanged(m['hostClientId'] as String?),
      'state' when m['state'] is Map => TogetherStateEvent(
        TogetherState.fromJson((m['state']! as Map).cast()),
      ),
      'cmd' when m['command'] is Map => _command((m['command']! as Map).cast()),
      'chat' => TogetherChat('${m['name'] ?? ''}', '${m['text'] ?? ''}'),
      'pong' => _pong(m['srvAt']),
      _ => null,
    };
    if (e != null && !_events.isClosed) _events.add(e);
  }

  static TogetherEvent _command(Map<String, Object?> c) => TogetherCommand(
    '${c['action']}',
    position: c['positionSeconds'] is num
        ? Duration(
            milliseconds: ((c['positionSeconds']! as num) * 1000).round(),
          )
        : null,
  );

  TogetherEvent? _pong(Object? serverAt) {
    final sent = _pingSentAt;
    if (sent != null && serverAt is num) {
      final now = DateTime.now().millisecondsSinceEpoch;
      clockOffset = serverAt.toInt() - (sent + now) ~/ 2;
    }
    return null;
  }

  void _ping() {
    _pingSentAt = DateTime.now().millisecondsSinceEpoch;
    _send({'t': 'ping'});
  }

  void _send(Map<String, Object?> msg) {
    try {
      _socket.add(jsonEncode(msg));
    } on Object {
      // Closing.
    }
  }

  /// The host tells the room where playback is.
  void sendState(TogetherState state) =>
      _send({'t': 'state', 'state': state.toJson()});

  /// A guest asks the host to play, pause or seek.
  void sendCommand(String action, {Duration? position}) => _send({
    't': 'cmd',
    'command': {
      'action': action,
      if (position != null) 'positionSeconds': position.inMilliseconds / 1000,
    },
  });

  void sendChat(String text) => _send({'t': 'chat', 'text': text});

  void _closed() {
    _pinger?.cancel();
    if (!_events.isClosed) {
      _events.add(const TogetherClosed());
      unawaited(_events.close());
    }
  }

  Future<void> close() async {
    _pinger?.cancel();
    await _socket.close();
    _closed();
  }
}
