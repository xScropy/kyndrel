import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final s = (await SettingsRepository.create()).load();
    expect(s.volume, 100);
    expect(s.skipSeconds, 10);
    expect(s.limiterEnabled, isTrue);
    expect(s.subtitleStyle, const SubtitleStyle());
  });

  test('round-trips through shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SettingsRepository.create();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            volume: 275,
            skipSeconds: 30,
            subtitleStyle: const SubtitleStyle(size: 60, bold: true),
            openSubtitlesApiKey: 'k',
          ),
        );
    final reloaded = (await SettingsRepository.create()).load();
    expect(reloaded.volume, 275);
    expect(reloaded.skipSeconds, 30);
    expect(reloaded.subtitleStyle.size, 60);
    expect(reloaded.subtitleStyle.bold, isTrue);
    expect(reloaded.openSubtitlesApiKey, 'k');
  });

  test('corrupt subtitle style falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'subtitleStyle': '{nope'});
    final s = (await SettingsRepository.create()).load();
    expect(s.subtitleStyle, const SubtitleStyle());
  });

  test('out-of-range volume is clamped', () async {
    SharedPreferences.setMockInitialValues({'volume': 999.0});
    expect((await SettingsRepository.create()).load().volume, 400);
  });
}
