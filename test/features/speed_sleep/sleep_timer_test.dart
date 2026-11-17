// fakeAsync drives the futures; awaiting them would deadlock the fake clock.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/features/speed_sleep/sleep_timer.dart';

import '../../support/fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late PlayerService service;
  late ProviderContainer container;

  void setUpIn(FakeAsync async) {
    backend = FakePlayerBackend();
    service = PlayerService(backend);
    container = ProviderContainer(
      overrides: [playerServiceProvider.overrideWithValue(service)],
    );
    async.flushMicrotasks();
  }

  SleepTimer timer() => container.read(sleepTimerProvider.notifier);
  SleepTimerState? state() => container.read(sleepTimerProvider);

  test('labels match the reference list', () {
    expect(SleepOption.all.map((o) => o.label), [
      '15 min',
      '30 min',
      '45 min',
      '1 hour',
      '2 hours',
      '3 hours',
      '4 hours',
      '6 hours',
      'End of episode',
      'End of next episode',
    ]);
  });

  test('fixed duration counts down, fades the last 30 s, pauses, restores', () {
    fakeAsync((async) {
      setUpIn(async);
      service.open('a.mkv');
      backend.emitPlaying(value: true);
      service.setVolume(200);
      async.flushMicrotasks();

      timer().select(const SleepAfter(Duration(minutes: 15)));
      async.flushMicrotasks();
      expect(state()?.remaining, const Duration(minutes: 15));

      async.elapse(const Duration(minutes: 10));
      expect(state()!.remaining!.inMinutes, 5);
      expect(service.state.volume, 200);

      // 15 s left: halfway through the fade.
      async.elapse(const Duration(minutes: 4, seconds: 45));
      expect(state()!.fading, isTrue);
      expect(service.state.volume, closeTo(100, 10));

      async.elapse(const Duration(seconds: 16));
      expect(state(), isNull);
      expect(backend.calls, contains('pause'));
      expect(service.state.volume, 200);
      container.dispose();
    });
  });

  test('selecting the active option again cancels and restores volume', () {
    fakeAsync((async) {
      setUpIn(async);
      service.setVolume(80);
      async.flushMicrotasks();
      const option = SleepAfter(Duration(minutes: 15));
      timer().select(option);
      async.elapse(const Duration(minutes: 14, seconds: 50));
      expect(service.state.volume, lessThan(80));
      timer().select(option);
      async.flushMicrotasks();
      expect(state(), isNull);
      expect(service.state.volume, 80);
      async.elapse(const Duration(minutes: 1));
      expect(backend.calls, isNot(contains('pause')));
      container.dispose();
    });
  });

  test('selecting a different option resets', () {
    fakeAsync((async) {
      setUpIn(async);
      timer().select(const SleepAfter(Duration(minutes: 15)));
      async.elapse(const Duration(minutes: 5));
      timer().select(const SleepAfter(Duration(minutes: 30)));
      async.flushMicrotasks();
      expect(state()?.remaining, const Duration(minutes: 30));
      container.dispose();
    });
  });

  test('end of episode pauses when the file completes', () {
    fakeAsync((async) {
      setUpIn(async);
      service.open('ep1.mkv');
      backend
        ..emitDuration(const Duration(minutes: 20))
        ..emitPosition(const Duration(minutes: 19))
        ..emitPlaying(value: true);
      timer().select(const SleepAtEndOfEpisode());
      async.elapse(const Duration(seconds: 1));
      expect(state()?.remaining, const Duration(minutes: 1));

      backend.emitCompleted(value: true);
      async.flushMicrotasks();
      expect(state(), isNull);
      expect(backend.calls, contains('pause'));
      container.dispose();
    });
  });

  test('end of next episode lets one more episode finish', () {
    fakeAsync((async) {
      setUpIn(async);
      service.open('ep1.mkv');
      backend.emitDuration(const Duration(minutes: 20));
      timer().select(const SleepAtEndOfEpisode(extraEpisodes: 1));
      async.flushMicrotasks();
      expect(state()?.episodesLeft, 1);
      expect(state()?.remaining, isNull, reason: 'not the final episode yet');

      backend.emitCompleted(value: true);
      async.flushMicrotasks();
      expect(state()?.episodesLeft, 0);
      expect(backend.calls, isNot(contains('pause')));

      service.open('ep2.mkv');
      backend
        ..emitDuration(const Duration(minutes: 20))
        ..emitPosition(const Duration(minutes: 2));
      async.elapse(const Duration(seconds: 1));
      expect(state()?.remaining, const Duration(minutes: 18));

      backend.emitCompleted(value: true);
      async.flushMicrotasks();
      expect(state(), isNull);
      expect(backend.calls, contains('pause'));
      container.dispose();
    });
  });

  test('episode remaining time accounts for playback speed', () {
    fakeAsync((async) {
      setUpIn(async);
      service.open('ep1.mkv');
      backend
        ..emitDuration(const Duration(minutes: 20))
        ..emitPosition(const Duration(minutes: 10));
      service.setRate(2);
      async.flushMicrotasks();
      timer().select(const SleepAtEndOfEpisode());
      async.elapse(const Duration(seconds: 1));
      expect(state()?.remaining, const Duration(minutes: 5));
      container.dispose();
    });
  });
}
