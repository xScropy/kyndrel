import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/playback/resume/resume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';
import '../../support/test_database.dart';

void main() {
  late FakePlayerBackend backend;
  late PlayerService service;
  late KyndrelDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.create();
    backend = FakePlayerBackend();
    service = PlayerService(backend);
    db = testDatabase();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        playerServiceProvider.overrideWithValue(service),
        databaseProvider.overrideWithValue(db),
      ],
    )..listen(resumeControllerProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ResumeRepository repo() => container.read(resumeRepositoryProvider);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  test('pausing saves the position', () async {
    await service.open('/v/a.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPlaying(value: true)
      ..emitPosition(const Duration(minutes: 12))
      ..emitPlaying(value: false);
    await settle();
    expect(
      (await repo().get('/v/a.mkv'))?.position,
      const Duration(minutes: 12),
    );
  });

  test('opening another file saves the previous one', () async {
    await service.open('/v/a.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPlaying(value: true)
      ..emitPosition(const Duration(minutes: 20));
    await service.open('/v/b.mkv');
    await settle();
    expect(
      (await repo().get('/v/a.mkv'))?.position,
      const Duration(minutes: 20),
    );
  });

  test('saveNow (app exit) saves while playing', () async {
    await service.open('/v/a.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPlaying(value: true)
      ..emitPosition(const Duration(minutes: 33));
    await settle();
    await container.read(resumeControllerProvider.notifier).saveNow();
    expect(
      (await repo().get('/v/a.mkv'))?.position,
      const Duration(minutes: 33),
    );
  });

  test('finishing a file forgets it', () async {
    await repo().save(
      '/v/a.mkv',
      const Duration(minutes: 5),
      const Duration(hours: 1),
    );
    await service.open('/v/a.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPosition(const Duration(hours: 1))
      ..emitCompleted(value: true);
    await settle();
    expect(await repo().get('/v/a.mkv'), isNull);
  });

  test('reopening offers to resume; accept seeks there', () async {
    await repo().save(
      '/v/a.mkv',
      const Duration(minutes: 7),
      const Duration(hours: 1),
    );
    await service.open('/v/a.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPlaying(value: true);
    await settle();
    final offer = container.read(resumeControllerProvider);
    expect(offer?.position, const Duration(minutes: 7));

    backend.calls.clear();
    await container.read(resumeControllerProvider.notifier).accept();
    expect(backend.calls, ['seek(420000)']);
    expect(container.read(resumeControllerProvider), isNull);
  });

  test('no offer for unknown files', () async {
    await service.open('/v/new.mkv');
    backend
      ..emitDuration(const Duration(hours: 1))
      ..emitPlaying(value: true);
    await settle();
    expect(container.read(resumeControllerProvider), isNull);
  });
}
