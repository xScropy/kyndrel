import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/net/together_client.dart';
import 'package:kyndrel/core/net/together_server.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/together/together_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';

/// Task 9.11: Watch Together.
void main() {
  Future<T> next<T extends TogetherEvent>(TogetherClient c) => c.events
      .firstWhere((e) => e is T)
      .then((e) => e as T)
      .timeout(const Duration(seconds: 5));

  test('the room: host, state, commands, chat, host hand-over', () async {
    final server = await TogetherServer.start();
    addTearDown(server.close);
    final url = Uri.parse('ws://127.0.0.1:${server.port}');
    final a = await TogetherClient.connect(
      server: url,
      room: 'ABC123',
      clientId: 'a',
      name: 'Ann',
    );
    final joinedA = await next<TogetherJoined>(a);
    expect(joinedA.hostId, 'a');

    final bJoined = TogetherClient.connect(
      server: url,
      room: 'ABC123',
      clientId: 'b',
      name: 'Ben',
    );
    final seen = next<TogetherPeerJoined>(a);
    final b = await bJoined;
    expect((await seen).peer.name, 'Ben');

    // The host's state reaches the guest, stamped by the server.
    final got = next<TogetherStateEvent>(b);
    a.sendState(
      const TogetherState(
        position: Duration(seconds: 42),
        playing: true,
        title: 'Film.mkv',
      ),
    );
    final s = (await got).state;
    expect(
      (s.position, s.playing, s.title),
      (const Duration(seconds: 42), true, 'Film.mkv'),
    );
    expect(s.serverAt, isNotNull);

    // A guest's state is ignored; its command goes to the host.
    final cmd = next<TogetherCommand>(a);
    b
      ..sendState(const TogetherState(position: Duration.zero, playing: false))
      ..sendCommand('seek', position: const Duration(seconds: 90));
    final c = await cmd;
    expect((c.action, c.position), ('seek', const Duration(seconds: 90)));

    final chat = next<TogetherChat>(b);
    a.sendChat('hi');
    expect(((await chat).name, (await chat).text), ('Ann', 'hi'));

    // The host leaves: the guest takes over.
    final host = next<TogetherHostChanged>(b);
    await a.close();
    expect((await host).hostId, 'b');
    await b.close();
  });

  test('invites: a code with the relay, or code@address on the network', () {
    expect(TogetherController.parseInvite('abc123', relay: 'wss://r.dev'), (
      'ABC123',
      Uri.parse('wss://r.dev'),
    ));
    expect(TogetherController.parseInvite('ABC123'), isNull);
    expect(TogetherController.parseInvite(' ABC123@192.168.1.5:7637 '), (
      'ABC123',
      Uri.parse('ws://192.168.1.5:7637'),
    ));
    expect(TogetherController.parseInvite('hello there'), isNull);
    expect(newRoomCode(), matches(RegExp(r'^[A-Z2-9]{6}$')));
  });

  test('two players stay in step through a room', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.create();
    ({ProviderContainer c, FakePlayerBackend b, PlayerService s}) player() {
      final b = FakePlayerBackend();
      final s = PlayerService(b);
      final c = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(s),
          settingsRepositoryProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(() async {
        await c.read(togetherProvider.notifier).leave();
        c.dispose();
        await s.dispose();
      });
      return (c: c, b: b, s: s);
    }

    Future<void> until(bool Function() ok, String what) async {
      for (var i = 0; i < 100 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(ok(), isTrue, reason: what);
    }

    final host = player();
    final guest = player();
    await host.s.open('/films/Film.mkv');
    await guest.s.open('/copy/Film.mkv');
    await host.c.read(togetherProvider.notifier).host(lan: true);
    final invite = host.c.read(togetherProvider)!.invite;
    final port = invite.split(':').last;
    final code = invite.split('@').first;
    await guest.c.read(togetherProvider.notifier).join('$code@127.0.0.1:$port');
    await until(
      () => (host.c.read(togetherProvider)?.peers.length ?? 0) == 2,
      'both in the room',
    );
    expect(guest.c.read(togetherProvider)!.isHost, isFalse);

    // The host plays from 10 min: the guest follows.
    host.b
      ..emitPosition(const Duration(minutes: 10))
      ..emitPlaying(value: true);
    await until(
      () => guest.b.calls.contains('play'),
      'guest plays: ${guest.b.calls}',
    );
    expect(guest.b.calls, contains('seek(600000)'));
    expect(guest.c.read(togetherProvider)!.hostTitle, isNull);

    // The guest pauses: the host is asked, and pauses.
    // (mpv reports the play it was told to do; the fake doesn't.)
    guest.b
      ..emitPosition(const Duration(minutes: 10))
      ..emitPlaying(value: true);
    guest.b.calls.clear();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    guest.b.emitPlaying(value: false);
    await until(
      () => host.b.calls.contains('pause'),
      'host pauses: ${host.b.calls}',
    );
  });
}
