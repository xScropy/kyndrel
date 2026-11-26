import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/power_state.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/library_previews.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';
import '../../support/fake_power_state.dart';
import '../../support/fake_storyboard_source.dart';
import '../../support/fake_window_service.dart';
import '../../support/test_database.dart';

/// Task 8.4: library videos get their coarse storyboard while idle.
void main() {
  late Directory cache;
  late KyndrelDatabase db;
  late FakePlayerBackend backend;
  late PlayerService service;
  late FakeStoryboardSource source;
  late FakePowerState power;

  Future<ProviderContainer> start({
    Map<String, Object> prefs = const {},
    bool mobile = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    cache = Directory.systemTemp.createTempSync('kyndrel_libprev');
    db = testDatabase();
    backend = FakePlayerBackend();
    service = PlayerService(backend);
    source = FakeStoryboardSource();
    power = FakePowerState();
    for (final (i, name) in ['old.mkv', 'new.mkv', 'song.mp3'].indexed) {
      await db
          .into(db.libraryItems)
          .insert(
            LibraryItemsCompanion.insert(
              uri: '/m/$name',
              name: name,
              folder: 'm',
              folderPath: '/m',
              kind: name.endsWith('.mp3') ? 'audio' : 'video',
              modified: DateTime(2026),
              added: DateTime(2026, 1, i + 1),
              durationMs: const Value(600000),
              probed: const Value(true),
            ),
          );
    }
    final container = ProviderContainer(
      overrides: [
        playerServiceProvider.overrideWithValue(service),
        windowServiceProvider.overrideWithValue(FakeWindowService()),
        settingsRepositoryProvider.overrideWithValue(
          await SettingsRepository.create(),
        ),
        databaseProvider.overrideWithValue(db),
        appCacheDirProvider.overrideWithValue(cache),
        libraryStoryboardSourceProvider.overrideWithValue(source),
        powerStateProvider.overrideWithValue(power),
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities(
            isDesktop: !mobile,
            hasWindowControls: !mobile,
            canRunExecutables: !mobile,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.dispose();
      await db.close();
      cache.deleteSync(recursive: true);
    });
    container.read(libraryPreviewsProvider);
    return container;
  }

  testWidgets('while idle: coarse storyboards, newest video first', (
    tester,
  ) async {
    final c = await start();
    await tester.pump(const Duration(seconds: 5));
    expect(source.rendered, isEmpty, reason: 'waits for quiet');
    await tester.pump(LibraryPreviewsController.startDelay);
    await tester.pump();
    expect(source.rendered.map((b) => b.source), ['/m/new.mkv', '/m/old.mkv']);
    expect(source.levelsAsked, [0, 0], reason: 'only the coarse level');
    expect(c.read(libraryPreviewsProvider).made, 2);
    expect(c.read(libraryPreviewsProvider).waiting, 0);
    final board = Storyboard.read(cache, '/m/new.mkv', const Duration(minutes: 10));
    expect(board.levels[0].complete, isTrue);

    // Done ones aren't made again.
    backend.emitVolume(50); // Any change pokes it.
    await tester.pump(LibraryPreviewsController.startDelay);
    await tester.pump();
    expect(source.rendered, hasLength(2));
  });

  testWidgets('playback stops the work and keeps it stopped', (tester) async {
    await start();
    backend.emitPlaying(value: true);
    await tester.pump(LibraryPreviewsController.startDelay * 2);
    expect(source.rendered, isEmpty);
    expect(source.cancels, greaterThan(0));
    backend.emitPlaying(value: false);
    await tester.pump(LibraryPreviewsController.startDelay);
    await tester.pump();
    expect(source.rendered, hasLength(2));
  });

  testWidgets('off: nothing', (tester) async {
    await start(prefs: {'libraryPreviews': 'off'});
    await tester.pump(LibraryPreviewsController.startDelay * 2);
    expect(source.rendered, isEmpty);
  });

  testWidgets('phones wait for the charger; nobody works in battery saver', (
    tester,
  ) async {
    await start(mobile: true);
    power.pluggedIn = false;
    await tester.pump(LibraryPreviewsController.startDelay);
    await tester.pump();
    expect(source.rendered, isEmpty);
    power.pluggedIn = true;
    await tester.pump(LibraryPreviewsController.powerRecheck);
    await tester.pump(LibraryPreviewsController.startDelay);
    await tester.pump();
    expect(source.rendered, hasLength(2));
  });

  testWidgets('battery saver pauses it even on desktop', (tester) async {
    await start();
    power.saver = true;
    await tester.pump(LibraryPreviewsController.startDelay * 2);
    expect(source.rendered, isEmpty);
  });
}
