import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/net/together_client.dart';
import 'package:kyndrel/core/net/together_server.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:path/path.dart' as p;

/// A line in the room's chat, or a notice ("Sara joined").
@immutable
class TogetherMessage {
  const new(this.name, this.text, {this.notice = false});
  final String name;
  final String text;
  final bool notice;
}

/// The room this Kyndrel is in (task 9.11).
@immutable
class TogetherSession {
  const new({
    required this.code,
    required this.invite,
    required this.isHost,
    this.peers = const [],
    this.messages = const [],
    this.hostTitle,
  });

  final String code;

  /// What to send friends: `CODE` with a relay, `CODE@192.168.1.5:7637` on
  /// the local network.
  final String invite;
  final bool isHost;
  final List<TogetherPeer> peers;
  final List<TogetherMessage> messages;

  /// The file the host is playing, when it isn't the same as ours.
  final String? hostTitle;

  TogetherSession copyWith({
    bool? isHost,
    List<TogetherPeer>? peers,
    List<TogetherMessage>? messages,
    String? Function()? hostTitle,
  }) => TogetherSession(
    code: code,
    invite: invite,
    isHost: isHost ?? this.isHost,
    peers: peers ?? this.peers,
    messages: messages ?? this.messages,
    hostTitle: hostTitle != null ? hostTitle() : this.hostTitle,
  );
}

/// Watch Together (task 9.11): everyone opens their own copy of the film;
/// the host's play, pause, seek and speed reach the others, and the
/// others' presses reach the host. Rooms run on a server one Kyndrel hosts
/// on the local network, or on the user's Cloudflare relay for friends
/// elsewhere.
class TogetherController extends Notifier<TogetherSession?> {
  TogetherClient? _client;
  TogetherServer? _server;
  StreamSubscription<TogetherEvent>? _events;
  StreamSubscription<PlaybackState>? _playback;
  Timer? _heartbeat;
  String? _hostId;
  PlaybackState? _last;

  /// While applying the room's state, our own player events are not news.
  DateTime _quietUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Guests follow the host when they drift further than this.
  static const tolerance = Duration(milliseconds: 1500);
  static const heartbeat = Duration(seconds: 5);
  static const lanPort = 7637;

  @override
  TogetherSession? build() {
    ref.onDispose(() => unawaited(_teardown()));
    return null;
  }

  String get _name {
    final n = ref.read(settingsProvider).togetherName.trim();
    if (n.isNotEmpty) return n;
    return Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        'Guest';
  }

  String _clientId() {
    final r = math.Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// Starts a room and joins it as the host. [lan] hosts it on this
  /// device even when a relay is set.
  Future<void> host({bool lan = false}) async {
    await leave();
    final code = newRoomCode();
    final relay = ref.read(settingsProvider).togetherRelay.trim();
    if (relay.isNotEmpty && !lan) {
      await _join(Uri.parse(relay), code, invite: code, host: true);
      return;
    }
    TogetherServer server;
    try {
      server = await TogetherServer.start(port: lanPort);
    } on SocketException {
      server = await TogetherServer.start();
    }
    _server = server;
    final ip = await localAddress();
    await _join(
      Uri.parse('ws://127.0.0.1:${server.port}'),
      code,
      invite: '$code@${ip ?? 'this-device'}:${server.port}',
      host: true,
    );
  }

  /// Joins from an invite: `CODE` (the relay in Settings) or
  /// `CODE@address:port` (a Kyndrel on the local network).
  Future<void> join(String invite) async {
    await leave();
    final parsed = parseInvite(
      invite,
      relay: ref.read(settingsProvider).togetherRelay.trim(),
    );
    if (parsed == null) throw const FormatException('Not an invite');
    await _join(parsed.$2, parsed.$1, invite: invite.trim(), host: false);
  }

  /// `(code, server)` from an invite, or null.
  static (String, Uri)? parseInvite(String invite, {String relay = ''}) {
    final t = invite.trim().toUpperCase();
    final m = RegExp(r'^([A-Z0-9]{4,8})(?:@(.+))?$').firstMatch(t);
    if (m == null) return null;
    final code = m[1]!;
    final at = m[2];
    if (at != null) {
      final host = invite.trim().substring(invite.trim().indexOf('@') + 1);
      return (code, Uri.parse(host.contains('://') ? host : 'ws://$host'));
    }
    if (relay.isEmpty) return null;
    return (code, Uri.parse(relay));
  }

  /// This device's address on the local network.
  static Future<String?> localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final i in interfaces) {
        for (final a in i.addresses) {
          if (!a.isLoopback && !a.isLinkLocal) return a.address;
        }
      }
    } on Object {
      // No network.
    }
    return null;
  }

  Future<void> _join(
    Uri server,
    String code, {
    required String invite,
    required bool host,
  }) async {
    final id = _clientId();
    final client = await TogetherClient.connect(
      server: server,
      room: code,
      clientId: id,
      name: _name,
    );
    _client = client;
    state = TogetherSession(code: code, invite: invite, isHost: host);
    _events = client.events.listen(_onEvent);
    final service = ref.read(playerServiceProvider);
    _last = service.state;
    _playback = service.states.listen(_onPlayback);
    _heartbeat = Timer.periodic(heartbeat, (_) {
      if (state?.isHost ?? false) _sendState(service.state);
    });
  }

  Future<void> leave() async {
    await _teardown();
    state = null;
  }

  Future<void> _teardown() async {
    _heartbeat?.cancel();
    await _events?.cancel();
    await _playback?.cancel();
    _events = null;
    _playback = null;
    final c = _client;
    _client = null;
    await c?.close();
    final s = _server;
    _server = null;
    await s?.close();
  }

  void say(String text) {
    if (text.trim().isEmpty) return;
    _client?.sendChat(text.trim());
  }

  void _add(TogetherMessage m) {
    final s = state;
    if (s == null) return;
    final list = [...s.messages, m];
    state = s.copyWith(
      messages: list.length > 50 ? list.sublist(list.length - 50) : list,
    );
  }

  String _nameOf(String id) =>
      state?.peers.where((p) => p.id == id).firstOrNull?.name ?? 'Someone';

  void _onEvent(TogetherEvent e) {
    final s = state;
    if (s == null) return;
    final me = _client?.clientId;
    switch (e) {
      case TogetherJoined(:final peers, :final hostId, state: final room):
        _hostId = hostId;
        state = s.copyWith(peers: peers, isHost: hostId == me);
        if (room != null && hostId != me) unawaited(_follow(room));
      case TogetherPeerJoined(:final peer):
        state = s.copyWith(peers: [...s.peers, peer]);
        _add(TogetherMessage(peer.name, 'joined', notice: true));
        // A newcomer gets where we are at once.
        if (s.isHost) _sendState(ref.read(playerServiceProvider).state);
      case TogetherPeerLeft(:final id):
        final name = _nameOf(id);
        state = s.copyWith(
          peers: [
            for (final p in s.peers)
              if (p.id != id) p,
          ],
        );
        _add(TogetherMessage(name, 'left', notice: true));
      case TogetherHostChanged(:final hostId):
        _hostId = hostId;
        state = s.copyWith(isHost: hostId == me);
      case TogetherStateEvent(state: final room):
        if (!s.isHost) unawaited(_follow(room));
      case TogetherCommand(:final action, :final position):
        if (s.isHost) unawaited(_apply(action, position));
      case TogetherChat(:final name, :final text):
        _add(TogetherMessage(name, text));
      case TogetherClosed():
        _add(const TogetherMessage('', 'Disconnected', notice: true));
    }
  }

  bool get _quiet => DateTime.now().isBefore(_quietUntil);

  void _hush() =>
      _quietUntil = DateTime.now().add(const Duration(milliseconds: 700));

  /// A guest catches up with the host's [room] state.
  Future<void> _follow(TogetherState room) async {
    final service = ref.read(playerServiceProvider);
    final me = service.state;
    final title = me.source == null ? null : p.basename(me.source!);
    state = state?.copyWith(
      hostTitle: () =>
          room.title != null && title != null && room.title != title
          ? room.title
          : null,
    );
    var target = room.position;
    final client = _client;
    if (room.playing && room.serverAt != null && client != null) {
      final elapsed = client.serverNow - room.serverAt!;
      if (elapsed > 0 && elapsed < 60000) {
        target += Duration(milliseconds: (elapsed * room.speed).round());
      }
    }
    _hush();
    if (me.rate != room.speed) await service.setRate(room.speed);
    if ((me.position - target).abs() > tolerance) await service.seek(target);
    if (room.playing && !me.isPlaying) await service.play();
    if (!room.playing && me.isPlaying) await service.pause();
  }

  /// The host does what a guest asked; the new state goes out by itself.
  Future<void> _apply(String action, Duration? position) async {
    final service = ref.read(playerServiceProvider);
    switch (action) {
      case 'play':
        await service.play();
      case 'pause':
        await service.pause();
      case 'seek' when position != null:
        await service.seek(position);
    }
  }

  void _sendState(PlaybackState s) {
    final source = s.source;
    _client?.sendState(
      TogetherState(
        position: s.position,
        playing: s.isPlaying,
        speed: s.rate,
        title: source == null ? null : p.basename(source),
      ),
    );
  }

  void _onPlayback(PlaybackState s) {
    final last = _last;
    _last = s;
    final session = state;
    if (session == null || last == null || _quiet) return;
    final toggled = s.isPlaying != last.isPlaying;
    final rate = s.rate != last.rate;
    // A jump, not playback moving along.
    final jumped =
        (s.position - last.position).abs() > const Duration(seconds: 2);
    if (!toggled && !rate && !jumped) return;
    if (session.isHost) {
      _sendState(s);
    } else if (_hostId != null) {
      // Guests ask the host, who decides for everyone.
      if (toggled) _client?.sendCommand(s.isPlaying ? 'play' : 'pause');
      if (jumped) _client?.sendCommand('seek', position: s.position);
    }
  }
}

final togetherProvider = NotifierProvider<TogetherController, TogetherSession?>(
  TogetherController.new,
);
