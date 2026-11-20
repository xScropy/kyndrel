import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/key_bindings.dart';
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

  test('every field survives a save and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SettingsRepository.create();
    const changed = AppSettings(
      volume: 150,
      skipSeconds: 30,
      upNextSeconds: 0,
      libraryFolders: ['/media/films', '/media/music'],
      libraryBookmarks: ['Ym9va21hcms='],
      gestureBrightness: false,
      gestureVolume: false,
      gestureSeek: false,
      gestureDoubleTap: false,
      gesturePinch: false,
      gestureLongPress: false,
      backgroundAudio: true,
      autoPip: false,

      limiterEnabled: false,
      showRemainingTime: true,
      autoLoadSubtitles: false,
      subtitleStyle: SubtitleStyle(size: 60),
      openSubtitlesApiKey: 'os',
      subtitleLanguages: 'ar',
      boostWarningSeen: true,
      autoPlayNextEpisode: false,
      tmdbApiKey: 'tm',
      screenshotFolder: '/s',
      screenshotWithSubtitles: true,
      translateProvider: 'deepl',
      translateTarget: 'fr',
      deeplApiKey: 'dl',
      googleTranslateApiKey: 'g',
      anthropicApiKey: 'a',
      downloadFolder: '/d',
      downloadTermsAccepted: true,
      recentUrls: ['https://x'],
      videoPreset: VideoPreset.sharpen,
      hwdec: 'no',
      deband: true,
      toneMapping: 'hable',
      equalizer: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      normalization: Normalization.loudnorm,
      scriptsEnabled: true,
      scriptsFolder: '/sc',
      keyBindings: KeyBindings({'mute': ''}),
      controlsHideSeconds: 5,
      showOsd: false,
      language: 'ar',
      mpvOptions: 'cache=yes',
      checkForUpdates: false,
      offerCrashReports: false,
    );
    await repo.save(changed);
    final r = (await SettingsRepository.create()).load();
    const defaults = AppSettings();
    // Compare via a field dump so a forgotten field shows up by name.
    Map<String, Object?> dump(AppSettings s) => {
      'volume': s.volume,
      'skipSeconds': s.skipSeconds,
      'upNextSeconds': s.upNextSeconds,
      'libraryFolders': s.libraryFolders,
      'libraryBookmarks': s.libraryBookmarks,
      'gestureBrightness': s.gestureBrightness,
      'gestureVolume': s.gestureVolume,
      'gestureSeek': s.gestureSeek,
      'gestureDoubleTap': s.gestureDoubleTap,
      'gesturePinch': s.gesturePinch,
      'gestureLongPress': s.gestureLongPress,
      'backgroundAudio': s.backgroundAudio,
      'autoPip': s.autoPip,
      'limiterEnabled': s.limiterEnabled,
      'showRemainingTime': s.showRemainingTime,
      'autoLoadSubtitles': s.autoLoadSubtitles,
      'subtitleStyle': s.subtitleStyle.toJson(),
      'openSubtitlesApiKey': s.openSubtitlesApiKey,
      'subtitleLanguages': s.subtitleLanguages,
      'boostWarningSeen': s.boostWarningSeen,
      'autoPlayNextEpisode': s.autoPlayNextEpisode,
      'tmdbApiKey': s.tmdbApiKey,
      'screenshotFolder': s.screenshotFolder,
      'screenshotWithSubtitles': s.screenshotWithSubtitles,
      'translateProvider': s.translateProvider,
      'translateTarget': s.translateTarget,
      'deeplApiKey': s.deeplApiKey,
      'googleTranslateApiKey': s.googleTranslateApiKey,
      'anthropicApiKey': s.anthropicApiKey,
      'downloadFolder': s.downloadFolder,
      'downloadTermsAccepted': s.downloadTermsAccepted,
      'recentUrls': s.recentUrls,
      'videoPreset': s.videoPreset,
      'hwdec': s.hwdec,
      'deband': s.deband,
      'toneMapping': s.toneMapping,
      'equalizer': s.equalizer,
      'normalization': s.normalization,
      'scriptsEnabled': s.scriptsEnabled,
      'scriptsFolder': s.scriptsFolder,
      'keyBindings': s.keyBindings,
      'controlsHideSeconds': s.controlsHideSeconds,
      'showOsd': s.showOsd,
      'language': s.language,
      'mpvOptions': s.mpvOptions,
      'checkForUpdates': s.checkForUpdates,
      'offerCrashReports': s.offerCrashReports,
    };
    final want = dump(changed);
    final got = dump(r);
    for (final k in want.keys) {
      expect(got[k], want[k], reason: k);
      expect(want[k], isNot(dump(defaults)[k]), reason: 'test changes $k');
    }
  });
}
