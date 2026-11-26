import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/library/history_controller.dart';
import 'package:kyndrel/features/library/library_home.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_harness.dart';
import '../../support/fake_player_backend.dart';
import '../../support/test_database.dart';

void main() {
  const hour = Duration(hours: 1);

  group('repository', () {
    late KyndrelDatabase db;
    late HistoryRepository repo;
    setUp(() {
      db = testDatabase();
      repo = HistoryRepository(db);
    });
    tearDown(() => db.close());

    test(
      'recent is newest first; continue skips finished and barely started',
      () async {
        await repo.record(
          source: 'a',
          title: 'A',
          position: const Duration(minutes: 20),
          duration: hour,
        );
        await repo.record(
          source: 'b',
          title: 'B',
          position: const Duration(minutes: 59, seconds: 50),
          duration: hour,
        );
        await repo.record(
          source: 'c',
          title: 'C',
          position: const Duration(seconds: 3),
          duration: hour,
        );
        final recent = await repo.watchRecent().first;
        expect(recent.map((e) => e.source), ['c', 'b', 'a']);
        expect(recent[1].finished, isTrue);
        final cont = await repo.watchContinue().first;
        expect(cont.map((e) => e.source), ['a']);
        expect(cont.first.progress, closeTo(1 / 3, 0.01));
      },
    );

    test('keeps the last thumbnail when a save has none', () async {
      await repo.record(
        source: 'a',
        title: 'A',
        position: const Duration(minutes: 5),
        duration: hour,
        thumbnailPath: '/t.jpg',
      );
      await repo.record(
        source: 'a',
        title: 'A',
        position: const Duration(minutes: 6),
        duration: hour,
      );
      expect((await repo.watchRecent().first).single.thumbnailPath, '/t.jpg');
    });

    test('remove and clear', () async {
      for (final s in ['a', 'b']) {
        await repo.record(
          source: s,
          title: s,
          position: const Duration(minutes: 5),
          duration: hour,
        );
      }
      await repo.remove('a');
      expect((await repo.watchRecent().first).single.source, 'b');
      await repo.clear();
      expect(await repo.watchRecent().first, isEmpty);
    });
  });

  group('controller', () {
    late FakePlayerBackend backend;
    late PlayerService service;
    late KyndrelDatabase db;
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.create();
      backend = FakePlayerBackend();
      service = PlayerService(backend);
      db = testDatabase();
      c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          playerServiceProvider.overrideWithValue(service),
          databaseProvider.overrideWithValue(db),
          appCacheDirProvider.overrideWithValue(Directory.systemTemp),
        ],
      )..listen(historyControllerProvider, (_, _) {});
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<List<HistoryItem>> recent() async {
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
      }
      return await c.read(historyRepositoryProvider).watchRecent().first;
    }

    test(
      'records on load, takes a thumbnail on pause, marks finished',
      () async {
        await service.open('/v/Show.S01E02.mkv');
        backend
          ..emitDuration(hour)
          ..emitSize(1920, 1080)
          ..emitPlaying(value: true);
        expect((await recent()).single.title, 'Show S01E02');

        backend
          ..emitPosition(const Duration(minutes: 30))
          ..emitPlaying(value: false);
        final item = (await recent()).single;
        expect(item.position, const Duration(minutes: 30));
        final shot = backend.commands.firstWhere(
          (cmd) => cmd.first == 'screenshot-to-file',
        );
        expect(shot[1], contains('thumbnails'));
        expect(shot.last, 'video');
        expect(item.thumbnailPath, shot[1]);

        backend
          ..emitPosition(hour)
          ..emitCompleted(value: true);
        expect((await recent()).single.finished, isTrue);
      },
    );

    test('incognito and private folders leave no history (8.6, 8.8)', () async {
      await c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(incognito: true));
      await service.open('/v/Secret.mkv');
      backend
        ..emitDuration(hour)
        ..emitPlaying(value: true);
      expect(await recent(), isEmpty);

      await c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(incognito: false));
      await c.read(libraryRepositoryProvider).setFolder('/p', private: true);
      await pumpEventQueue();
      await service.open('/p/Private.mkv');
      backend
        ..emitDuration(hour)
        ..emitPlaying(value: true);
      expect(await recent(), isEmpty);

      await service.open('/v/Public.mkv');
      backend
        ..emitDuration(hour)
        ..emitPlaying(value: true);
      expect((await recent()).single.source, '/v/Public.mkv');
    });
  });

  test('relativeDate', () {
    final now = DateTime(2026, 11, 17, 12);
    expect(relativeDate(now, now: now), 'Just now');
    expect(
      relativeDate(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(relativeDate(DateTime(2026, 11, 16, 23), now: now), 'Yesterday');
    expect(relativeDate(DateTime(2026, 11, 14), now: now), '3 days ago');
    expect(relativeDate(DateTime(2026, 10), now: now), '2026-10-01');
  });

  testWidgets('start screen shows continue watching and recent; resume jumps', (
    tester,
  ) async {
    final h = await AppHarness.create();
    final repo = HistoryRepository(h.db);
    await tester.runAsync(() async {
      await repo.record(
        source: '/v/Film.2019.mkv',
        title: 'Film',
        position: const Duration(minutes: 20),
        duration: hour,
      );
      await ResumeRepository(h.db)
          .save('/v/Film.2019.mkv', const Duration(minutes: 20), hour);
    });
    await h.pump(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text('CONTINUE WATCHING'), findsOneWidget);
    expect(find.text('40 min left'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-/v/Film.2019.mkv')));
    await tester.pump();
    expect(h.backend.calls, contains('open(/v/Film.2019.mkv, play: true)'));
    h.backend.calls.clear();
    h.load();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(h.backend.calls, contains('seek(1200000)'));
    expect(find.byKey(const Key('resume-banner')), findsNothing);
  });

  test('launch options import kept', () {
    expect(const LaunchOptions().source, isNull);
  });
}
