import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/media_session_sync.dart';
import 'package:kyndrel/core/platform/media_session.dart';
import 'package:kyndrel/core/platform/mpris.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';
import '../../support/test_database.dart';

class _FakeSession implements MediaSession {
  final updates = <MediaSessionState>[];
  final _commands = StreamController<MediaCommand>.broadcast(sync: true);
  void send(MediaCommand c) => _commands.add(c);

  @override
  Stream<MediaCommand> get commands => _commands.stream;
  @override
  Future<void> update(MediaSessionState state) async => updates.add(state);
  @override
  Future<void> dispose() async {}
}

void main() {
  group('sync', () {
    late FakePlayerBackend backend;
    late PlayerService service;
    late _FakeSession session;
    late ProviderContainer c;
    late KyndrelDatabase db;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backend = FakePlayerBackend();
      service = PlayerService(backend);
      session = _FakeSession();
      db = testDatabase();
      c = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(service),
          mediaSessionProvider.overrideWithValue(session),
          databaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(
            await SettingsRepository.create(),
          ),
        ],
      )..read(mediaSessionSyncProvider);
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('publishes title and state, position at most once a second', () async {
      await service.open('/v/Show.Name.S01E02.mkv');
      backend
        ..emitDuration(const Duration(minutes: 20))
        ..emitPlaying(value: true);
      for (var i = 1; i <= 5; i++) {
        backend.emitPosition(Duration(milliseconds: 100 * i));
      }
      await pumpEventQueue();
      final last = session.updates.last;
      expect(last.title, 'Show Name');
      expect(last.subtitle, 'S01E02');
      expect(last.playing, isTrue);
      expect(last.duration, const Duration(minutes: 20));
      expect(
        session.updates.where((u) => u.playing).length,
        lessThan(3),
        reason: 'small position steps are throttled',
      );
    });

    test('OS commands drive the player', () async {
      await service.open('/v/a.mkv');
      backend
        ..emitDuration(const Duration(minutes: 20))
        ..emitPosition(const Duration(minutes: 1));
      backend.calls.clear();
      session
        ..send(const PlayPauseCommand())
        ..send(const SeekToCommand(Duration(minutes: 5)))
        ..send(const SeekByCommand(Duration(seconds: -30)))
        ..send(const SetVolumeCommand(0.5));
      await pumpEventQueue();
      expect(backend.calls, [
        'play',
        'seek(300000)',
        'seek(30000)',
        'volume(50.0)',
      ]);
    });
  });

  test(
    'channel session: update goes to native, calls become commands',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('kyndrel/media_session');
      final sent = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent.add(call);
            return null;
          });
      final s = ChannelMediaSession();
      final cmds = <MediaCommand>[];
      s.commands.listen(cmds.add);
      await s.update(const MediaSessionState(title: 'Film', playing: true));
      expect(sent.single.method, 'update');
      expect((sent.single.arguments as Map)['title'], 'Film');

      Future<void> native(String method, [Object? args]) =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
                channel.name,
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall(method, args),
                ),
                (_) {},
              );
      await native('next');
      await native('seekTo', 61000);
      expect(cmds[0], isA<NextCommand>());
      expect((cmds[1] as SeekToCommand).position, const Duration(seconds: 61));
      await s.dispose();
    },
  );

  group('MPRIS on a real session bus', () {
    Process? daemon;
    late String address;

    setUpAll(() async {
      try {
        daemon = await Process.start('dbus-daemon', [
          '--session',
          '--print-address',
          '--nofork',
        ]);
        address =
            (await daemon!.stdout
                    .transform(utf8.decoder)
                    .transform(const LineSplitter())
                    .first)
                .trim();
      } on ProcessException {
        daemon = null;
      }
    });
    tearDownAll(() => daemon?.kill());

    test('properties, commands and volume', () async {
      if (daemon == null) {
        markTestSkipped('dbus-daemon not installed');
        return;
      }
      final server = DBusClient(DBusAddress(address));
      final session = await MprisMediaSession.start(
        client: server,
        busName: 'org.mpris.MediaPlayer2.kyndrel_test',
      );
      expect(session, isA<MprisMediaSession>());
      final cmds = <MediaCommand>[];
      session.commands.listen(cmds.add);
      await session.update(
        const MediaSessionState(
          title: 'The Film',
          playing: true,
          position: Duration(seconds: 30),
          duration: Duration(minutes: 90),
          canNext: true,
        ),
      );

      final client = DBusClient(DBusAddress(address));
      final player = DBusRemoteObject(
        client,
        name: 'org.mpris.MediaPlayer2.kyndrel_test',
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      const iface = 'org.mpris.MediaPlayer2.Player';
      expect(
        (await player.getProperty(iface, 'PlaybackStatus')).asString(),
        'Playing',
      );
      final meta = (await player.getProperty(
        iface,
        'Metadata',
      )).asStringVariantDict();
      expect(meta['xesam:title']!.asString(), 'The Film');
      expect(meta['mpris:length']!.asInt64(), 90 * 60 * 1000000);
      expect(
        (await player.getProperty(iface, 'CanGoNext')).asBoolean(),
        isTrue,
      );
      expect(
        (await player.getProperty(
          'org.mpris.MediaPlayer2',
          'Identity',
        )).asString(),
        'Kyndrel',
      );

      await player.callMethod(iface, 'PlayPause', []);
      await player.callMethod(iface, 'Next', []);
      await player.callMethod(iface, 'Seek', [const DBusInt64(10000000)]);
      await player.callMethod(iface, 'SetPosition', [
        DBusObjectPath('/dev/kyndrel/track/current'),
        const DBusInt64(120000000),
      ]);
      await player.setProperty(iface, 'Volume', const DBusDouble(0.25));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cmds[0], isA<PlayPauseCommand>());
      expect(cmds[1], isA<NextCommand>());
      expect((cmds[2] as SeekByCommand).offset, const Duration(seconds: 10));
      expect((cmds[3] as SeekToCommand).position, const Duration(minutes: 2));
      expect((cmds[4] as SetVolumeCommand).volume, 0.25);

      await client.close();
      await session.dispose();
    });
  });
}
