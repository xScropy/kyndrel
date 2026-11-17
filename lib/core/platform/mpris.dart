import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:kyndrel/core/platform/media_session.dart';

const _root = 'org.mpris.MediaPlayer2';
const _player = 'org.mpris.MediaPlayer2.Player';
const _path = DBusObjectPath.unchecked('/org/mpris/MediaPlayer2');
const _trackId = DBusObjectPath.unchecked('/dev/kyndrel/track/current');

/// Linux media session on D-Bus (MPRIS 2), so media keys, GNOME/KDE media
/// widgets and `playerctl` control Kyndrel (task 4.8).
class MprisMediaSession extends DBusObject implements MediaSession {
  new _(this._client) : super(_path);

  /// Registers `org.mpris.MediaPlayer2.kyndrel` on the session bus. Returns
  /// a no-op session when there's no bus.
  static Future<MediaSession> start({
    DBusClient? client,
    String busName = 'org.mpris.MediaPlayer2.kyndrel',
  }) async {
    if (client == null &&
        Platform.environment['DBUS_SESSION_BUS_ADDRESS'] == null) {
      return const NoopMediaSession();
    }
    final c = client ?? DBusClient.session();
    try {
      final s = MprisMediaSession._(c);
      await c.registerObject(s);
      await c.requestName(busName);
      return s;
    } on Object {
      await c.close();
      return const NoopMediaSession();
    }
  }

  final DBusClient _client;
  final _commands = StreamController<MediaCommand>.broadcast();
  MediaSessionState _state = const MediaSessionState();

  @override
  Stream<MediaCommand> get commands => _commands.stream;

  String get _status => _state.title == null
      ? 'Stopped'
      : _state.playing
      ? 'Playing'
      : 'Paused';

  DBusValue _metadata() => DBusDict.stringVariant({
    'mpris:trackid': _trackId,
    if (_state.duration > Duration.zero)
      'mpris:length': DBusInt64(_state.duration.inMicroseconds),
    if (_state.title != null) 'xesam:title': DBusString(_state.title!),
    if (_state.subtitle != null) 'xesam:album': DBusString(_state.subtitle!),
    if (_state.artUrl != null) 'mpris:artUrl': DBusString(_state.artUrl!),
  });

  Map<String, DBusValue> _playerProps() => {
    'PlaybackStatus': DBusString(_status),
    'LoopStatus': const DBusString('None'),
    'Rate': const DBusDouble(1),
    'Shuffle': const DBusBoolean(false),
    'Metadata': _metadata(),
    'Volume': DBusDouble(_state.volume),
    'Position': DBusInt64(_state.position.inMicroseconds),
    'MinimumRate': const DBusDouble(0.1),
    'MaximumRate': const DBusDouble(4),
    'CanGoNext': DBusBoolean(_state.canNext),
    'CanGoPrevious': DBusBoolean(_state.canPrevious),
    'CanPlay': DBusBoolean(_state.title != null),
    'CanPause': DBusBoolean(_state.title != null),
    'CanSeek': DBusBoolean(_state.duration > Duration.zero),
    'CanControl': const DBusBoolean(true),
  };

  static final Map<String, DBusValue> _rootProps = {
    'CanQuit': const DBusBoolean(false),
    'CanRaise': const DBusBoolean(true),
    'HasTrackList': const DBusBoolean(false),
    'Identity': const DBusString('Kyndrel'),
    'DesktopEntry': const DBusString('kyndrel'),
    'SupportedUriSchemes': DBusArray.string(const ['file', 'http', 'https']),
    'SupportedMimeTypes': DBusArray.string(const [
      'video/mp4',
      'video/x-matroska',
    ]),
  };

  @override
  Future<void> update(MediaSessionState state) async {
    final old = _playerProps();
    _state = state;
    final now = _playerProps();
    final changed = <String, DBusValue>{
      for (final e in now.entries)
        if (e.key != 'Position' && old[e.key] != e.value) e.key: e.value,
    };
    if (changed.isNotEmpty) {
      await emitPropertiesChanged(_player, changedProperties: changed);
    }
    // A jump (seek) is announced with the Seeked signal.
    final jump =
        state.position -
        Duration(microseconds: (old['Position']! as DBusInt64).value);
    if (jump.abs() > const Duration(seconds: 3)) {
      await emitSignal(_player, 'Seeked', [
        DBusInt64(state.position.inMicroseconds),
      ]);
    }
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final call = methodCall;
    final args = call.values;
    MediaCommand? cmd;
    if (call.interface == _root) {
      cmd = switch (call.name) {
        'Raise' => const RaiseCommand(),
        _ => null,
      };
      if (call.name == 'Quit' || cmd != null) {
        if (cmd != null) _commands.add(cmd);
        return DBusMethodSuccessResponse();
      }
    }
    if (call.interface == _player) {
      cmd = switch (call.name) {
        'Play' => const PlayCommand(),
        'Pause' => const PauseCommand(),
        'PlayPause' => const PlayPauseCommand(),
        'Stop' => const StopCommand(),
        'Next' => const NextCommand(),
        'Previous' => const PreviousCommand(),
        'Seek' when args.isNotEmpty => SeekByCommand(
          Duration(microseconds: args.first.asInt64()),
        ),
        'SetPosition' when args.length == 2 => SeekToCommand(
          Duration(microseconds: args[1].asInt64()),
        ),
        _ => null,
      };
      if (cmd != null) {
        _commands.add(cmd);
        return DBusMethodSuccessResponse();
      }
      if (call.name == 'OpenUri') return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final props = interface == _root ? _rootProps : _playerProps();
    final v = props[name];
    return v == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(v);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == _root ? _rootProps : _playerProps(),
      );

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface == _player && name == 'Volume') {
      _commands.add(SetVolumeCommand(value.asDouble().clamp(0, 1)));
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.propertyReadOnly();
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      _root,
      methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
      properties: [
        for (final e in _rootProps.entries)
          DBusIntrospectProperty(e.key, e.value.signature),
      ],
    ),
    DBusIntrospectInterface(
      _player,
      methods: [
        for (final m in [
          'Play',
          'Pause',
          'PlayPause',
          'Stop',
          'Next',
          'Previous',
        ])
          DBusIntrospectMethod(m),
        DBusIntrospectMethod(
          'Seek',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
            ),
          ],
        ),
        DBusIntrospectMethod(
          'SetPosition',
          args: [
            DBusIntrospectArgument(
              DBusSignature('o'),
              DBusArgumentDirection.in_,
            ),
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
            ),
          ],
        ),
      ],
      signals: [
        DBusIntrospectSignal(
          'Seeked',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.out,
            ),
          ],
        ),
      ],
      properties: [
        for (final e in _playerProps().entries)
          DBusIntrospectProperty(
            e.key,
            e.value.signature,
            access: e.key == 'Volume'
                ? DBusPropertyAccess.readwrite
                : DBusPropertyAccess.read,
          ),
      ],
    ),
  ];

  @override
  Future<void> dispose() async {
    await _commands.close();
    await _client.close();
  }
}
