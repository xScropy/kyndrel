import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
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
    );
  }
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
