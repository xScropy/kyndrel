import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/core/ui/key_bindings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// When library videos get their coarse storyboard in advance (task 8.4).
enum LibraryPreviews {
  /// Always on desktop; only while charging on phones.
  auto,
  always,
  charging,
  off,
}

/// User preferences (shared_preferences). Persisted on every change.
@immutable
class AppSettings {
  const new({
    this.volume = 100,
    this.skipSeconds = 10,
    this.upNextSeconds = 10,
    this.libraryFolders = const [],
    this.libraryBookmarks = const [],
    this.musicWaves = true,
    this.reduceMotion = false,
    this.gestureBrightness = true,
    this.gestureVolume = true,
    this.gestureSeek = true,
    this.gestureDoubleTap = true,
    this.gesturePinch = true,
    this.gestureLongPress = true,
    this.backgroundAudio = false,
    this.autoPip = true,
    this.limiterEnabled = true,
    this.showRemainingTime = false,
    this.autoLoadSubtitles = true,
    this.subtitleStyle = const SubtitleStyle(),
    this.openSubtitlesApiKey = '',
    this.subtitleLanguages = 'en',
    this.boostWarningSeen = false,
    this.volumeBoostMax = 500,
    this.showClock = true,
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
    this.videoPreset = VideoPreset.standard,
    this.hwdec = 'auto-safe',
    this.deband = false,
    this.toneMapping = 'auto',
    this.equalizer = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.normalization = Normalization.off,
    this.scriptsEnabled = false,
    this.scriptsFolder = '',
    this.keyBindings = const KeyBindings(),
    this.controlsHideSeconds = 3,
    this.showOsd = true,
    this.language = 'system',
    this.mpvOptions = '',
    this.checkForUpdates = true,
    this.offerCrashReports = true,
    this.libraryPreviews = LibraryPreviews.auto,
    this.frameCacheMb = 500,
    this.incognito = false,
    this.amoledBlack = false,
    this.rememberFileSettings = true,
    this.showHeatmap = true,
    this.skipIntro = true,
    this.privatePin = '',
    this.browseServers = const [],
    this.audioPassthrough = false,
    this.audioDevice = 'auto',
    this.customCommands = const [],
    this.mouseMiddle = 'playPause',
    this.mouseSide = 'seek',
  });

  /// Last volume, 0–500.
  final double volume;

  /// Length of the back/forward skip and the ←/→ seek (task 1.5).
  final int skipSeconds;

  /// "Up next" countdown before the queue moves on; 0 = straight away.
  final int upNextSeconds;

  /// Desktop library folders (task 7.3); empty means the user's Videos
  /// (Movies) and Music folders.
  final List<String> libraryFolders;

  /// macOS: access to [libraryFolders] across restarts (sandbox bookmarks).
  final List<String> libraryBookmarks;

  /// Music view (task 7.6): waves that follow the loudness.
  final bool musicWaves;

  /// Less movement: the disc stays still and the waves are gentle.
  final bool reduceMotion;

  // Touch gestures on the video (task 6.3), each on by default.
  /// Left-side vertical swipe: screen brightness.
  final bool gestureBrightness;

  /// Right-side vertical swipe: volume (phone, then boost).
  final bool gestureVolume;

  /// Horizontal swipe: seek with a preview.
  final bool gestureSeek;

  /// Double-tap the sides: back/forward by the skip length.
  final bool gestureDoubleTap;

  /// Pinch: zoom the picture.
  final bool gesturePinch;

  /// Long-press: 2× speed while held.
  final bool gestureLongPress;

  /// Phones (task 6.6): keep playing the sound after leaving the app.
  final bool backgroundAudio;

  /// Phones: going Home while a video plays opens picture-in-picture.
  final bool autoPip;

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

  /// The top of the volume slider, 100–500 % (task 9.1); 100 turns the
  /// boost off.
  final double volumeBoostMax;

  /// Harbor's clock in full screen: the time and when the film ends.
  final bool showClock;

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

  // Video quality (4.6) and audio effects (4.7).
  final VideoPreset videoPreset;
  final String hwdec;
  final bool deband;
  final String toneMapping;

  /// 10 band gains in dB.
  final List<double> equalizer;
  final Normalization normalization;

  /// mpv user scripts (4.9): off by default, scripts can do anything.
  final bool scriptsEnabled;

  /// Empty means `<app support>/scripts`.
  final String scriptsFolder;

  /// Shortcut overrides (5.1).
  final KeyBindings keyBindings;

  /// Appearance (5.1).
  final int controlsHideSeconds;
  final bool showOsd;

  /// `system`, `en` or `ar` (5.2).
  final String language;

  /// `name=value` lines passed to mpv (5.1, advanced).
  final String mpvOptions;

  /// Look for a newer release on start (5.6).
  final bool checkForUpdates;

  /// After a crash, offer to open a pre-filled bug report (5.7).
  final bool offerCrashReports;

  /// When library videos get their storyboard in advance (task 8.4).
  final LibraryPreviews libraryPreviews;

  /// Size limit of the storyboard cache in MB (task 8.4).
  final int frameCacheMb;

  /// Nothing goes into history, resume points or per-file settings
  /// (task 8.8).
  final bool incognito;

  /// Pure black backgrounds for OLED screens (task 8.8).
  final bool amoledBlack;

  /// Each file keeps its own tracks, speed, zoom and delays (task 8.8).
  final bool rememberFileSettings;

  /// The "most replayed" shading above the seek bar (task 8.10).
  final bool showHeatmap;

  /// Offer "Skip intro" where an episode's opening is known (task 8.9).
  final bool skipIntro;

  /// Hash of the PIN that opens private folders; empty when none is set
  /// (task 8.6). A privacy curtain, not encryption: the files stay where
  /// they are.
  final String privatePin;

  /// Saved network servers for Browse, as JSON (task 8.7). Passwords are
  /// not saved: they are asked for once per session.
  final List<String> browseServers;

  /// AC-3/DTS/TrueHD go untouched to an AV receiver (task 8.8).
  final bool audioPassthrough;

  /// mpv's audio output device (`audio-device`); `auto` follows the
  /// system's default.
  final String audioDevice;

  /// The user's quick commands, `Label | mpv command` each (task 8.8).
  final List<String> customCommands;

  /// What the middle mouse button does: `playPause`, `mute`, `fullscreen`,
  /// `screenshot` or `none` (task 8.8).
  final String mouseMiddle;

  /// What the back/forward mouse buttons do: `seek`, `playlist` or
  /// `none` (task 8.8).
  final String mouseSide;

  static const hideChoices = [2, 3, 5, 10];

  static const frameCacheChoices = [200, 500, 1000, 2000];

  static const skipChoices = [5, 10, 15, 30, 60];
  static const upNextChoices = [0, 5, 10, 15, 30];

  AppSettings copyWith({
    double? volume,
    int? skipSeconds,
    int? upNextSeconds,
    List<String>? libraryFolders,
    List<String>? libraryBookmarks,
    bool? musicWaves,
    bool? reduceMotion,
    bool? gestureBrightness,
    bool? gestureVolume,
    bool? gestureSeek,
    bool? gestureDoubleTap,
    bool? gesturePinch,
    bool? gestureLongPress,
    bool? backgroundAudio,
    bool? autoPip,
    bool? limiterEnabled,
    bool? showRemainingTime,
    bool? autoLoadSubtitles,
    SubtitleStyle? subtitleStyle,
    String? openSubtitlesApiKey,
    String? subtitleLanguages,
    bool? boostWarningSeen,
    double? volumeBoostMax,
    bool? showClock,
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
    VideoPreset? videoPreset,
    String? hwdec,
    bool? deband,
    String? toneMapping,
    List<double>? equalizer,
    Normalization? normalization,
    bool? scriptsEnabled,
    String? scriptsFolder,
    KeyBindings? keyBindings,
    int? controlsHideSeconds,
    bool? showOsd,
    String? language,
    String? mpvOptions,
    bool? checkForUpdates,
    bool? offerCrashReports,
    LibraryPreviews? libraryPreviews,
    int? frameCacheMb,
    bool? incognito,
    bool? amoledBlack,
    bool? rememberFileSettings,
    bool? showHeatmap,
    bool? skipIntro,
    String? privatePin,
    List<String>? browseServers,
    bool? audioPassthrough,
    String? audioDevice,
    List<String>? customCommands,
    String? mouseMiddle,
    String? mouseSide,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      skipSeconds: skipSeconds ?? this.skipSeconds,
      upNextSeconds: upNextSeconds ?? this.upNextSeconds,
      libraryFolders: libraryFolders ?? this.libraryFolders,
      libraryBookmarks: libraryBookmarks ?? this.libraryBookmarks,
      musicWaves: musicWaves ?? this.musicWaves,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      gestureBrightness: gestureBrightness ?? this.gestureBrightness,
      gestureVolume: gestureVolume ?? this.gestureVolume,
      gestureSeek: gestureSeek ?? this.gestureSeek,
      gestureDoubleTap: gestureDoubleTap ?? this.gestureDoubleTap,
      gesturePinch: gesturePinch ?? this.gesturePinch,
      gestureLongPress: gestureLongPress ?? this.gestureLongPress,
      backgroundAudio: backgroundAudio ?? this.backgroundAudio,
      autoPip: autoPip ?? this.autoPip,
      limiterEnabled: limiterEnabled ?? this.limiterEnabled,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      autoLoadSubtitles: autoLoadSubtitles ?? this.autoLoadSubtitles,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      openSubtitlesApiKey: openSubtitlesApiKey ?? this.openSubtitlesApiKey,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      boostWarningSeen: boostWarningSeen ?? this.boostWarningSeen,
      volumeBoostMax: volumeBoostMax ?? this.volumeBoostMax,
      showClock: showClock ?? this.showClock,
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
      videoPreset: videoPreset ?? this.videoPreset,
      hwdec: hwdec ?? this.hwdec,
      deband: deband ?? this.deband,
      toneMapping: toneMapping ?? this.toneMapping,
      equalizer: equalizer ?? this.equalizer,
      normalization: normalization ?? this.normalization,
      scriptsEnabled: scriptsEnabled ?? this.scriptsEnabled,
      scriptsFolder: scriptsFolder ?? this.scriptsFolder,
      keyBindings: keyBindings ?? this.keyBindings,
      controlsHideSeconds: controlsHideSeconds ?? this.controlsHideSeconds,
      showOsd: showOsd ?? this.showOsd,
      language: language ?? this.language,
      mpvOptions: mpvOptions ?? this.mpvOptions,
      checkForUpdates: checkForUpdates ?? this.checkForUpdates,
      offerCrashReports: offerCrashReports ?? this.offerCrashReports,
      libraryPreviews: libraryPreviews ?? this.libraryPreviews,
      frameCacheMb: frameCacheMb ?? this.frameCacheMb,
      incognito: incognito ?? this.incognito,
      amoledBlack: amoledBlack ?? this.amoledBlack,
      rememberFileSettings: rememberFileSettings ?? this.rememberFileSettings,
      showHeatmap: showHeatmap ?? this.showHeatmap,
      skipIntro: skipIntro ?? this.skipIntro,
      privatePin: privatePin ?? this.privatePin,
      browseServers: browseServers ?? this.browseServers,
      audioPassthrough: audioPassthrough ?? this.audioPassthrough,
      audioDevice: audioDevice ?? this.audioDevice,
      customCommands: customCommands ?? this.customCommands,
      mouseMiddle: mouseMiddle ?? this.mouseMiddle,
      mouseSide: mouseSide ?? this.mouseSide,
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
      volume: (_prefs.getDouble('volume') ?? d.volume).clamp(0, 500),
      skipSeconds: _prefs.getInt('skipSeconds') ?? d.skipSeconds,
      upNextSeconds: _prefs.getInt('upNextSeconds') ?? d.upNextSeconds,
      libraryFolders:
          _prefs.getStringList('libraryFolders') ?? d.libraryFolders,
      libraryBookmarks:
          _prefs.getStringList('libraryBookmarks') ?? d.libraryBookmarks,
      musicWaves: _prefs.getBool('musicWaves') ?? d.musicWaves,
      reduceMotion: _prefs.getBool('reduceMotion') ?? d.reduceMotion,
      gestureBrightness:
          _prefs.getBool('gestureBrightness') ?? d.gestureBrightness,
      gestureVolume: _prefs.getBool('gestureVolume') ?? d.gestureVolume,
      gestureSeek: _prefs.getBool('gestureSeek') ?? d.gestureSeek,
      gestureDoubleTap:
          _prefs.getBool('gestureDoubleTap') ?? d.gestureDoubleTap,
      gesturePinch: _prefs.getBool('gesturePinch') ?? d.gesturePinch,
      gestureLongPress:
          _prefs.getBool('gestureLongPress') ?? d.gestureLongPress,
      backgroundAudio: _prefs.getBool('backgroundAudio') ?? d.backgroundAudio,
      autoPip: _prefs.getBool('autoPip') ?? d.autoPip,
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
      volumeBoostMax: (_prefs.getDouble('volumeBoostMax') ?? d.volumeBoostMax)
          .clamp(100, 500)
          .toDouble(),
      showClock: _prefs.getBool('showClock') ?? d.showClock,
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
      downloadFolder: _prefs.getString('downloadFolder') ?? d.downloadFolder,
      downloadTermsAccepted:
          _prefs.getBool('downloadTermsAccepted') ?? d.downloadTermsAccepted,
      recentUrls: _prefs.getStringList('recentUrls') ?? d.recentUrls,
      videoPreset: _enum(VideoPreset.values, 'videoPreset', d.videoPreset),
      hwdec: _prefs.getString('hwdec') ?? d.hwdec,
      deband: _prefs.getBool('deband') ?? d.deband,
      toneMapping: _prefs.getString('toneMapping') ?? d.toneMapping,
      equalizer: _gains() ?? d.equalizer,
      normalization: _enum(
        Normalization.values,
        'normalization',
        d.normalization,
      ),
      scriptsEnabled: _prefs.getBool('scriptsEnabled') ?? d.scriptsEnabled,
      scriptsFolder: _prefs.getString('scriptsFolder') ?? d.scriptsFolder,
      keyBindings: _bindings() ?? d.keyBindings,
      controlsHideSeconds:
          _prefs.getInt('controlsHideSeconds') ?? d.controlsHideSeconds,
      showOsd: _prefs.getBool('showOsd') ?? d.showOsd,
      language: _prefs.getString('language') ?? d.language,
      mpvOptions: _prefs.getString('mpvOptions') ?? d.mpvOptions,
      checkForUpdates: _prefs.getBool('checkForUpdates') ?? d.checkForUpdates,
      offerCrashReports:
          _prefs.getBool('offerCrashReports') ?? d.offerCrashReports,
      libraryPreviews: _enum(
        LibraryPreviews.values,
        'libraryPreviews',
        d.libraryPreviews,
      ),
      frameCacheMb: _prefs.getInt('frameCacheMb') ?? d.frameCacheMb,
      incognito: _prefs.getBool('incognito') ?? d.incognito,
      amoledBlack: _prefs.getBool('amoledBlack') ?? d.amoledBlack,
      rememberFileSettings:
          _prefs.getBool('rememberFileSettings') ?? d.rememberFileSettings,
      showHeatmap: _prefs.getBool('showHeatmap') ?? d.showHeatmap,
      skipIntro: _prefs.getBool('skipIntro') ?? d.skipIntro,
      privatePin: _prefs.getString('privatePin') ?? d.privatePin,
      browseServers: _prefs.getStringList('browseServers') ?? d.browseServers,
      audioPassthrough:
          _prefs.getBool('audioPassthrough') ?? d.audioPassthrough,
      audioDevice: _prefs.getString('audioDevice') ?? d.audioDevice,
      customCommands:
          _prefs.getStringList('customCommands') ?? d.customCommands,
      mouseMiddle: _prefs.getString('mouseMiddle') ?? d.mouseMiddle,
      mouseSide: _prefs.getString('mouseSide') ?? d.mouseSide,
    );
  }

  T _enum<T extends Enum>(List<T> values, String key, T fallback) {
    final name = _prefs.getString(key);
    return values.where((v) => v.name == name).firstOrNull ?? fallback;
  }

  KeyBindings? _bindings() {
    final raw = _prefs.getString('keyBindings');
    if (raw == null) return null;
    try {
      return KeyBindings(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v')),
      );
    } on FormatException {
      return null;
    }
  }

  List<double>? _gains() {
    final raw = _prefs.getStringList('equalizer');
    if (raw == null || raw.length != 10) return null;
    final g = raw.map(double.tryParse).toList();
    return g.contains(null) ? null : g.cast<double>();
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setDouble('volume', s.volume);
    await _prefs.setInt('skipSeconds', s.skipSeconds);
    await _prefs.setInt('upNextSeconds', s.upNextSeconds);
    await _prefs.setStringList('libraryFolders', s.libraryFolders);
    await _prefs.setStringList('libraryBookmarks', s.libraryBookmarks);
    await _prefs.setBool('musicWaves', s.musicWaves);
    await _prefs.setBool('reduceMotion', s.reduceMotion);
    await _prefs.setBool('gestureBrightness', s.gestureBrightness);
    await _prefs.setBool('gestureVolume', s.gestureVolume);
    await _prefs.setBool('gestureSeek', s.gestureSeek);
    await _prefs.setBool('gestureDoubleTap', s.gestureDoubleTap);
    await _prefs.setBool('gesturePinch', s.gesturePinch);
    await _prefs.setBool('gestureLongPress', s.gestureLongPress);
    await _prefs.setBool('backgroundAudio', s.backgroundAudio);
    await _prefs.setBool('autoPip', s.autoPip);
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
    await _prefs.setDouble('volumeBoostMax', s.volumeBoostMax);
    await _prefs.setBool('showClock', s.showClock);
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
    await _prefs.setString('videoPreset', s.videoPreset.name);
    await _prefs.setString('hwdec', s.hwdec);
    await _prefs.setBool('deband', s.deband);
    await _prefs.setString('toneMapping', s.toneMapping);
    await _prefs.setStringList('equalizer', [
      for (final g in s.equalizer) '$g',
    ]);
    await _prefs.setString('normalization', s.normalization.name);
    await _prefs.setBool('scriptsEnabled', s.scriptsEnabled);
    await _prefs.setString('scriptsFolder', s.scriptsFolder);
    await _prefs.setString('keyBindings', jsonEncode(s.keyBindings.overrides));
    await _prefs.setInt('controlsHideSeconds', s.controlsHideSeconds);
    await _prefs.setBool('showOsd', s.showOsd);
    await _prefs.setString('language', s.language);
    await _prefs.setString('mpvOptions', s.mpvOptions);
    await _prefs.setBool('checkForUpdates', s.checkForUpdates);
    await _prefs.setBool('offerCrashReports', s.offerCrashReports);
    await _prefs.setString('libraryPreviews', s.libraryPreviews.name);
    await _prefs.setInt('frameCacheMb', s.frameCacheMb);
    await _prefs.setBool('incognito', s.incognito);
    await _prefs.setBool('amoledBlack', s.amoledBlack);
    await _prefs.setBool('rememberFileSettings', s.rememberFileSettings);
    await _prefs.setBool('showHeatmap', s.showHeatmap);
    await _prefs.setBool('skipIntro', s.skipIntro);
    await _prefs.setString('privatePin', s.privatePin);
    await _prefs.setStringList('browseServers', s.browseServers);
    await _prefs.setBool('audioPassthrough', s.audioPassthrough);
    await _prefs.setString('audioDevice', s.audioDevice);
    await _prefs.setStringList('customCommands', s.customCommands);
    await _prefs.setString('mouseMiddle', s.mouseMiddle);
    await _prefs.setString('mouseSide', s.mouseSide);
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
