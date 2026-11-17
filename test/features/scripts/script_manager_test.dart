import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/features/scripts/script_manager.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';

void main() {
  late Directory dir;
  late FakePlayerBackend backend;
  late ProviderContainer c;

  Future<void> setUpWith({required bool enabled}) async {
    dir = Directory.systemTemp.createTempSync('kyndrel_scripts');
    for (final n in ['b.js', 'a.lua', 'notes.txt']) {
      File(p.join(dir.path, n)).writeAsStringSync('');
    }
    SharedPreferences.setMockInitialValues({
      'scriptsEnabled': enabled,
      'scriptsFolder': dir.path,
    });
    backend = FakePlayerBackend();
    c = ProviderContainer(
      overrides: [
        playerServiceProvider.overrideWithValue(PlayerService(backend)),
        settingsRepositoryProvider.overrideWithValue(
          await SettingsRepository.create(),
        ),
      ],
    )..listen(scriptManagerProvider, (_, _) {});
    await pumpEventQueue();
  }

  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  List<List<String>> loads() =>
      backend.commands.where((x) => x.first == 'load-script').toList();

  test('disabled: found but not loaded', () async {
    await setUpWith(enabled: false);
    final s = c.read(scriptManagerProvider);
    expect(s.found.map(p.basename), ['a.lua', 'b.js']);
    expect(loads(), isEmpty);
  });

  test(
    'enabled: loads each script once, even across setting changes',
    () async {
      await setUpWith(enabled: true);
      expect(loads().map((x) => p.basename(x[1])), ['a.lua', 'b.js']);
      await c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(skipSeconds: 30));
      File(p.join(dir.path, 'c.lua')).writeAsStringSync('');
      await c.read(scriptManagerProvider.notifier).loadAll();
      expect(loads().map((x) => p.basename(x[1])), ['a.lua', 'b.js', 'c.lua']);
    },
  );

  test('turning scripts on loads them', () async {
    await setUpWith(enabled: false);
    await c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(scriptsEnabled: true));
    await pumpEventQueue();
    expect(loads(), hasLength(2));
  });

  test('scripts can show on-screen messages', () async {
    await setUpWith(enabled: false);
    // mpv hands user-data back JSON-encoded.
    backend.emitProperty('user-data/kyndrel/osd', '"Hello from Lua"');
    await pumpEventQueue();
    expect(c.read(osdProvider), 'Hello from Lua');
  });
}
