import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/playlist/up_next.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late ProviderContainer container;

  // SharedPreferences resolves on the real event loop: load it before
  // entering fake time.
  Future<SettingsRepository> repoWith(int seconds) {
    SharedPreferences.setMockInitialValues({'upNextSeconds': seconds});
    return SettingsRepository.create();
  }

  void setUpIn(FakeAsync async, SettingsRepository repo) {
    backend = FakePlayerBackend();
    final service = PlayerService(backend);
    container =
        ProviderContainer(
            overrides: [
              playerServiceProvider.overrideWithValue(service),
              settingsRepositoryProvider.overrideWithValue(repo),
            ],
          )
          ..listen(playlistProvider, (_, _) {})
          ..listen(upNextProvider, (_, _) {})
          ..listen(playbackStateProvider, (_, _) {});
    unawaited(
      container.read(playlistProvider.notifier).openAll([
        '/tv/Show.S01E01.mkv',
        '/tv/Show.S01E02.mkv',
      ]),
    );
    async.flushMicrotasks();
    backend
      ..emitDuration(const Duration(minutes: 20))
      ..emitPosition(const Duration(minutes: 20))
      ..emitCompleted(value: true);
    async.flushMicrotasks();
  }

  List<String> opened() =>
      backend.calls.where((c) => c.startsWith('open(')).toList();
  UpNext? upNext() => container.read(upNextProvider);

  test('counts down, then plays the next item', () async {
    final repo = await repoWith(10);
    fakeAsync((async) {
      setUpIn(async, repo);
      expect(upNext()?.source, '/tv/Show.S01E02.mkv');
      expect(upNext()?.secondsLeft, 10);
      expect(opened(), hasLength(1));

      async.elapse(const Duration(seconds: 4));
      expect(upNext()?.secondsLeft, 6);

      async.elapse(const Duration(seconds: 6));
      expect(upNext(), isNull);
      expect(opened().last, contains('Show.S01E02.mkv'));
      container.dispose();
    });
  });

  test('Cancel stays on the finished episode', () async {
    final repo = await repoWith(10);
    fakeAsync((async) {
      setUpIn(async, repo);
      container.read(upNextProvider.notifier).cancel();
      async.elapse(const Duration(seconds: 30));
      expect(opened(), hasLength(1));
      container.dispose();
    });
  });

  test('seeking back into the finished file cancels it', () async {
    final repo = await repoWith(10);
    fakeAsync((async) {
      setUpIn(async, repo);
      unawaited(
        container.read(playerServiceProvider).seek(const Duration(minutes: 19)),
      );
      backend.emitCompleted(value: false);
      async.flushMicrotasks();
      expect(upNext(), isNull);
      async.elapse(const Duration(seconds: 30));
      expect(opened(), hasLength(1));
      container.dispose();
    });
  });

  test('a countdown of 0 moves on straight away', () async {
    final repo = await repoWith(0);
    fakeAsync((async) {
      setUpIn(async, repo);
      expect(upNext(), isNull);
      expect(opened().last, contains('Show.S01E02.mkv'));
      container.dispose();
    });
  });
}
