import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences (shared_preferences). Persisted on every change.
@immutable
class AppSettings {
  const new({
    this.volume = 100,
    this.skipSeconds = 10,
    this.limiterEnabled = true,
    this.showRemainingTime = false,
    this.autoLoadSubtitles = true,
    this.subtitleStyle = const SubtitleStyle(),
    this.openSubtitlesApiKey = '',
    this.subtitleLanguages = 'en',
    this.boostWarningSeen = false,
    this.autoPlayNextEpisode = true,
    this.tmdbApiKey = '',
    this.screenshotFolder = '',
    this.screenshotWithSubtitles = false,
    this.translateProvider = 'claude',
    this.translateTarget = 'en',
    this.deeplApiKey = '',
    this.googleTranslateApiKey = '',
    this.anthropicApiKey = '',
    this.downloadFolder = '',
    this.downloadTermsAccepted = false,
    this.recentUrls = const [],
  });

  /// Last volume, 0–400.
  final double volume;

  /// Length of the back/forward skip and the ←/→ seek (task 1.5).
  final int skipSeconds;

  /// Limiter above 100 % volume (task 1.6).
  final bool limiterEnabled;

  /// Seek bar shows `-remaining` instead of the total.
  final bool showRemainingTime;
  final bool autoLoadSubtitles;
  final SubtitleStyle subtitleStyle;
  final String openSubtitlesApiKey;

  /// Comma-separated ISO 639-1 codes for online search, e.g. `en,ar`.
  final String subtitleLanguages;

  /// The one-time warning about boosting above 100 % has been shown.
  final bool boostWarningSeen;

  /// Opening an episode queues the next ones from the same folder (3.2).
  final bool autoPlayNextEpisode;

  /// TMDB v3 key or v4 read token for titles and posters (3.4).
  final String tmdbApiKey;

  /// Where screenshots go; empty means `~/Pictures/Kyndrel` (3.8).
  final String screenshotFolder;
  final bool screenshotWithSubtitles;

  /// Subtitle translation (4.2): `deepl`, `google` or `claude`.
  final String translateProvider;

  /// ISO 639-1 target language.
  final String translateTarget;
  final String deeplApiKey;
  final String googleTranslateApiKey;
  final String anthropicApiKey;

  /// Where downloads go; empty means `~/Downloads` (4.3).
  final String downloadFolder;

  /// The user confirmed they only download what they may save.
  final bool downloadTermsAccepted;

  /// Last network URLs opened, newest first, without passwords (4.5).
  final List<String> recentUrls;

  static const skipChoices = [5, 10, 15, 30, 60];

  AppSettings copyWith({
    double? volume,
    int? skipSeconds,
    bool? limiterEnabled,
    bool? showRemainingTime,
    bool? autoLoadSubtitles,
    SubtitleStyle? subtitleStyle,
    String? openSubtitlesApiKey,
    String? subtitleLanguages,
    bool? boostWarningSeen,
    bool? autoPlayNextEpisode,
    String? tmdbApiKey,
    String? screenshotFolder,
    bool? screenshotWithSubtitles,
    String? translateProvider,
    String? translateTarget,
    String? deeplApiKey,
    String? googleTranslateApiKey,
    String? anthropicApiKey,
    String? downloadFolder,
    bool? downloadTermsAccepted,
    List<String>? recentUrls,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      skipSeconds: skipSeconds ?? this.skipSeconds,
      limiterEnabled: limiterEnabled ?? this.limiterEnabled,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      autoLoadSubtitles: autoLoadSubtitles ?? this.autoLoadSubtitles,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      openSubtitlesApiKey: openSubtitlesApiKey ?? this.openSubtitlesApiKey,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      boostWarningSeen: boostWarningSeen ?? this.boostWarningSeen,
      autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
      tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
      screenshotFolder: screenshotFolder ?? this.screenshotFolder,
      screenshotWithSubtitles:
          screenshotWithSubtitles ?? this.screenshotWithSubtitles,
      translateProvider: translateProvider ?? this.translateProvider,
      translateTarget: translateTarget ?? this.translateTarget,
      deeplApiKey: deeplApiKey ?? this.deeplApiKey,
      googleTranslateApiKey:
          googleTranslateApiKey ?? this.googleTranslateApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      downloadFolder: downloadFolder ?? this.downloadFolder,
      downloadTermsAccepted:
          downloadTermsAccepted ?? this.downloadTermsAccepted,
      recentUrls: recentUrls ?? this.recentUrls,
    );
  }
}

/// `~/Pictures/Kyndrel` (Windows: `%USERPROFILE%\Pictures\Kyndrel`), the
/// screenshot folder when none is set (task 3.8).
String defaultScreenshotFolder([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final home = e['USERPROFILE'] ?? e['HOME'] ?? Directory.systemTemp.path;
  return p.join(home, 'Pictures', 'Kyndrel');
}

/// `~/Downloads` (Windows: `%USERPROFILE%\Downloads`), the download folder
/// when none is set (task 4.3).
String defaultDownloadFolder([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final home = e['USERPROFILE'] ?? e['HOME'] ?? Directory.systemTemp.path;
  return p.join(home, 'Downloads');
}

/// Reads and writes [AppSettings].
class SettingsRepository {
  new(this._prefs);

  static Future<SettingsRepository> create() async =>
      SettingsRepository(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  AppSettings load() {
    const d = AppSettings();
    var style = d.subtitleStyle;
    final styleJson = _prefs.getString('subtitleStyle');
    if (styleJson != null) {
      try {
        style = SubtitleStyle.fromJson(
          (jsonDecode(styleJson) as Map).cast<String, Object?>(),
        );
      } on FormatException {
        // Keep the default on corrupt data.
      }
    }
    return AppSettings(
      volume: (_prefs.getDouble('volume') ?? d.volume).clamp(0, 400),
      skipSeconds: _prefs.getInt('skipSeconds') ?? d.skipSeconds,
      limiterEnabled: _prefs.getBool('limiterEnabled') ?? d.limiterEnabled,
      showRemainingTime:
          _prefs.getBool('showRemainingTime') ?? d.showRemainingTime,
      autoLoadSubtitles:
          _prefs.getBool('autoLoadSubtitles') ?? d.autoLoadSubtitles,
      subtitleStyle: style,
      openSubtitlesApiKey:
          _prefs.getString('openSubtitlesApiKey') ?? d.openSubtitlesApiKey,
      subtitleLanguages:
          _prefs.getString('subtitleLanguages') ?? d.subtitleLanguages,
      boostWarningSeen:
          _prefs.getBool('boostWarningSeen') ?? d.boostWarningSeen,
      autoPlayNextEpisode:
          _prefs.getBool('autoPlayNextEpisode') ?? d.autoPlayNextEpisode,
      tmdbApiKey: _prefs.getString('tmdbApiKey') ?? d.tmdbApiKey,
      screenshotFolder:
          _prefs.getString('screenshotFolder') ?? d.screenshotFolder,
      screenshotWithSubtitles:
          _prefs.getBool('screenshotWithSubtitles') ??
          d.screenshotWithSubtitles,
      translateProvider:
          _prefs.getString('translateProvider') ?? d.translateProvider,
      translateTarget: _prefs.getString('translateTarget') ?? d.translateTarget,
      deeplApiKey: _prefs.getString('deeplApiKey') ?? d.deeplApiKey,
      googleTranslateApiKey:
          _prefs.getString('googleTranslateApiKey') ?? d.googleTranslateApiKey,
      anthropicApiKey: _prefs.getString('anthropicApiKey') ?? d.anthropicApiKey,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setDouble('volume', s.volume);
    await _prefs.setInt('skipSeconds', s.skipSeconds);
    await _prefs.setBool('limiterEnabled', s.limiterEnabled);
    await _prefs.setBool('showRemainingTime', s.showRemainingTime);
    await _prefs.setBool('autoLoadSubtitles', s.autoLoadSubtitles);
    await _prefs.setString(
      'subtitleStyle',
      jsonEncode(s.subtitleStyle.toJson()),
    );
    await _prefs.setString('openSubtitlesApiKey', s.openSubtitlesApiKey);
    await _prefs.setString('subtitleLanguages', s.subtitleLanguages);
    await _prefs.setBool('boostWarningSeen', s.boostWarningSeen);
    await _prefs.setBool('autoPlayNextEpisode', s.autoPlayNextEpisode);
    await _prefs.setString('tmdbApiKey', s.tmdbApiKey);
    await _prefs.setString('screenshotFolder', s.screenshotFolder);
    await _prefs.setBool('screenshotWithSubtitles', s.screenshotWithSubtitles);
    await _prefs.setString('translateProvider', s.translateProvider);
    await _prefs.setString('translateTarget', s.translateTarget);
    await _prefs.setString('deeplApiKey', s.deeplApiKey);
    await _prefs.setString('googleTranslateApiKey', s.googleTranslateApiKey);
    await _prefs.setString('anthropicApiKey', s.anthropicApiKey);
    await _prefs.setString('downloadFolder', s.downloadFolder);
    await _prefs.setBool('downloadTermsAccepted', s.downloadTermsAccepted);
    await _prefs.setStringList('recentUrls', s.recentUrls);
  }
}

/// Overridden in `main.dart` (and tests) with a loaded repository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw UnimplementedError('settingsRepositoryProvider not overridden'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  /// Applies [change] and persists the result.
  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}
