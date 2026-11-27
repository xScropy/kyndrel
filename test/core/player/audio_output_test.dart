import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/engine_sync.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';

import '../../support/app_harness.dart';
import '../../support/fake_player_backend.dart';

/// When the sound device doesn't open, Kyndrel says so and retries,
/// instead of playing in silence.
void main() {
  test('a device that fails: reported, retried once per file', () {
    fakeAsync((async) {
      final backend = FakePlayerBackend();
      final service = PlayerService(backend);
      final problems = <String>[];
      service.audioProblems.listen(problems.add);
      unawaited(service.open('/v/a.mkv'));
      async.flushMicrotasks();

      backend.emitError('Could not open/initialize audio device -> no sound.');
      async.flushMicrotasks();
      expect(problems, hasLength(1));
      // Not an error: the film still plays.
      expect(service.state.errorMessage, isNull);
      expect(service.state.status, isNot(PlaybackStatus.error));
      expect(backend.commands, isNot(contains(['ao-reload'])));
      async.elapse(PlayerService.audioRetryDelay);
      expect(
        backend.commands.where((c) => c.first == 'ao-reload'),
        hasLength(1),
      );

      // Failing again: reported, but no retry loop.
      backend.emitError('[ao/wasapi] audio output failed');
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2));
      expect(problems, hasLength(2));
      expect(
        backend.commands.where((c) => c.first == 'ao-reload'),
        hasLength(1),
      );

      // The next file gets its own retry.
      unawaited(service.open('/v/b.mkv'));
      async.flushMicrotasks();
      backend.emitError('Could not open/initialize audio device -> no sound.');
      async
        ..flushMicrotasks()
        ..elapse(PlayerService.audioRetryDelay);
      expect(
        backend.commands.where((c) => c.first == 'ao-reload'),
        hasLength(2),
      );
      unawaited(service.dispose());
      async.flushMicrotasks();
    });
  });

  test('output devices from mpv; automatic first', () async {
    final backend = FakePlayerBackend();
    final service = PlayerService(backend);
    addTearDown(service.dispose);
    backend.properties['audio-device-list'] = jsonEncode([
      {'name': 'auto', 'description': 'Autoselect device'},
      {'name': 'wasapi/{abc}', 'description': 'Speakers (Realtek)'},
      {'name': 'wasapi/{hdmi}', 'description': ''},
    ]);
    final devices = await service.audioDevices();
    expect(
      [for (final d in devices) d.description],
      ['Automatic', 'Speakers (Realtek)', 'wasapi/{hdmi}'],
    );
    await service.setAudioDevice('wasapi/{abc}');
    expect(backend.properties['audio-device'], 'wasapi/{abc}');
    await service.setAudioDevice('');
    expect(backend.properties['audio-device'], 'auto');
    expect(SoundDevice.parseList('not json'), [SoundDevice.automatic]);
    expect(SoundDevice.parseList(null), [SoundDevice.automatic]);
  });

  testWidgets('the app says why there is no sound', (tester) async {
    final h = await AppHarness.create(prefs: {'audioPassthrough': true});
    await h.pump(tester, launch: const LaunchOptions(source: '/v/a.mkv'));
    h.load(duration: const Duration(minutes: 10));
    await tester.pump();
    h.backend.emitError('Could not open/initialize audio device -> no sound.');
    await tester.pump();
    expect(find.text(audioProblemPassthroughText), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
