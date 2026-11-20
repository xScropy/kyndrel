import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @playTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play (Space)'**
  String get playTooltip;

  /// No description provided for @pauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause (Space)'**
  String get pauseTooltip;

  /// No description provided for @previousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous (P)'**
  String get previousTooltip;

  /// No description provided for @nextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next (N)'**
  String get nextTooltip;

  /// No description provided for @backSeconds.
  ///
  /// In en, this message translates to:
  /// **'Back {seconds} s'**
  String backSeconds(int seconds);

  /// No description provided for @forwardSeconds.
  ///
  /// In en, this message translates to:
  /// **'Forward {seconds} s'**
  String forwardSeconds(int seconds);

  /// No description provided for @muteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute (M)'**
  String get muteTooltip;

  /// No description provided for @unmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute (M)'**
  String get unmuteTooltip;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @fullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Full screen (F)'**
  String get fullscreenTooltip;

  /// No description provided for @exitFullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen (F)'**
  String get exitFullscreenTooltip;

  /// No description provided for @showTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Show total time'**
  String get showTotalTime;

  /// No description provided for @showRemainingTime.
  ///
  /// In en, this message translates to:
  /// **'Show remaining time'**
  String get showRemainingTime;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @mediaInfo.
  ///
  /// In en, this message translates to:
  /// **'Media info'**
  String get mediaInfo;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get closeEsc;

  /// No description provided for @copyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get copyLog;

  /// No description provided for @fitAndAspect.
  ///
  /// In en, this message translates to:
  /// **'Fit & aspect'**
  String get fitAndAspect;

  /// No description provided for @fitHeader.
  ///
  /// In en, this message translates to:
  /// **'FIT'**
  String get fitHeader;

  /// No description provided for @zoomHeader.
  ///
  /// In en, this message translates to:
  /// **'ZOOM'**
  String get zoomHeader;

  /// No description provided for @rotateHeader.
  ///
  /// In en, this message translates to:
  /// **'ROTATE'**
  String get rotateHeader;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @rotateClockwise.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° clockwise'**
  String get rotateClockwise;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @openMediaHeader.
  ///
  /// In en, this message translates to:
  /// **'OPEN MEDIA'**
  String get openMediaHeader;

  /// No description provided for @openFileShortcut.
  ///
  /// In en, this message translates to:
  /// **'Open file…  (Ctrl+O)'**
  String get openFileShortcut;

  /// No description provided for @pastePathOrUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste a path or URL'**
  String get pastePathOrUrl;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'Or drop a file anywhere in the window. Ctrl+N opens streams, shares and WebDAV folders.'**
  String get dropHint;

  /// No description provided for @resumeFrom.
  ///
  /// In en, this message translates to:
  /// **'Resume from {time}?'**
  String resumeFrom(String time);

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @speedAndSleep.
  ///
  /// In en, this message translates to:
  /// **'Speed & sleep'**
  String get speedAndSleep;

  /// No description provided for @speedOsd.
  ///
  /// In en, this message translates to:
  /// **'Speed {rate}'**
  String speedOsd(String rate);

  /// No description provided for @playbackSpeedHeader.
  ///
  /// In en, this message translates to:
  /// **'PLAYBACK SPEED'**
  String get playbackSpeedHeader;

  /// No description provided for @sleepTimerHeader.
  ///
  /// In en, this message translates to:
  /// **'SLEEP TIMER'**
  String get sleepTimerHeader;

  /// No description provided for @sleepCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the same option again to cancel.'**
  String get sleepCancelHint;

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get defaultBadge;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @queueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue (Q)'**
  String get queueTooltip;

  /// No description provided for @queueCountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue · {count} (Q)'**
  String queueCountTooltip(int count);

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue · {count}'**
  String queueTitle(int count);

  /// No description provided for @shuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get shuffleOn;

  /// No description provided for @shuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle off'**
  String get shuffleOff;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOne;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'The queue is empty.'**
  String get queueEmpty;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WATCHING'**
  String get continueWatching;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get recent;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get removeFromHistory;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @menuOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file…'**
  String get menuOpenFile;

  /// No description provided for @menuOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder…'**
  String get menuOpenFolder;

  /// No description provided for @menuOpenClipboard.
  ///
  /// In en, this message translates to:
  /// **'Open from clipboard'**
  String get menuOpenClipboard;

  /// No description provided for @menuOpenStream.
  ///
  /// In en, this message translates to:
  /// **'Open network stream…'**
  String get menuOpenStream;

  /// No description provided for @menuEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details…'**
  String get menuEditDetails;

  /// No description provided for @menuScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot  (Ctrl+S)'**
  String get menuScreenshot;

  /// No description provided for @menuSubtitlesAudio.
  ///
  /// In en, this message translates to:
  /// **'Subtitles & audio'**
  String get menuSubtitlesAudio;

  /// No description provided for @menuEffects.
  ///
  /// In en, this message translates to:
  /// **'Video & audio effects…'**
  String get menuEffects;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get menuSettings;

  /// No description provided for @dropToPlay.
  ///
  /// In en, this message translates to:
  /// **'Drop to play'**
  String get dropToPlay;

  /// No description provided for @subtitlesAudioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Subtitles & audio (S)'**
  String get subtitlesAudioTooltip;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @subtitlesHeader.
  ///
  /// In en, this message translates to:
  /// **'SUBTITLES'**
  String get subtitlesHeader;

  /// No description provided for @audioHeader.
  ///
  /// In en, this message translates to:
  /// **'AUDIO'**
  String get audioHeader;

  /// No description provided for @syncOffset.
  ///
  /// In en, this message translates to:
  /// **'Sync offset'**
  String get syncOffset;

  /// No description provided for @style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @subtitleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Title, or \"Show S01E02\"'**
  String get subtitleSearchHint;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @findMoreSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Find more subtitles'**
  String get findMoreSubtitles;

  /// No description provided for @loadFile.
  ///
  /// In en, this message translates to:
  /// **'Load file'**
  String get loadFile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get settingsSubtitles;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get settingsEffects;

  /// No description provided for @settingsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get settingsVideo;

  /// No description provided for @settingsPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get settingsPicture;

  /// No description provided for @settingsShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsShortcuts;

  /// No description provided for @settingsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @openSourceLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get openSourceLicences;

  /// No description provided for @diagnosticsHeader.
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTICS'**
  String get diagnosticsHeader;

  /// No description provided for @hardwareDecoding.
  ///
  /// In en, this message translates to:
  /// **'Hardware decoding: {hwdec}'**
  String hardwareDecoding(String hwdec);

  /// No description provided for @softwareDecoding.
  ///
  /// In en, this message translates to:
  /// **'Software decoding'**
  String get softwareDecoding;

  /// No description provided for @seekLabel.
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get seekLabel;

  /// No description provided for @seekValue.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} of {total}'**
  String seekValue(String elapsed, String total);

  /// No description provided for @videoSurface.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoSurface;

  /// No description provided for @videoSurfaceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to show controls, double-tap for full screen'**
  String get videoSurfaceHint;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Kyndrel {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install and restart'**
  String get updateInstall;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateWhatsNew;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update… {percent} %'**
  String updateDownloading(int percent);

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Kyndrel is up to date.'**
  String get updateUpToDate;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates: {reason}'**
  String updateFailed(String reason);

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckNow;

  /// No description provided for @crashTitle.
  ///
  /// In en, this message translates to:
  /// **'Kyndrel stopped unexpectedly'**
  String get crashTitle;

  /// No description provided for @crashBodyExit.
  ///
  /// In en, this message translates to:
  /// **'The last session ended without closing normally. Would you like to report it? This opens a GitHub issue in your browser with the version, your OS and the end of the log filled in. You can edit or discard it before sending.'**
  String get crashBodyExit;

  /// No description provided for @crashBodyError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong in the last session. Would you like to report it? This opens a pre-filled GitHub issue in your browser; nothing is sent unless you submit it.'**
  String get crashBodyError;

  /// No description provided for @crashReport.
  ///
  /// In en, this message translates to:
  /// **'Report on GitHub'**
  String get crashReport;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @viewLog.
  ///
  /// In en, this message translates to:
  /// **'View log'**
  String get viewLog;

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logTitle;

  /// No description provided for @logCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get logCopy;

  /// No description provided for @logCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get logCopied;

  /// No description provided for @logOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get logOpenFolder;

  /// No description provided for @logEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get logEmpty;

  /// No description provided for @logLevelAndUp.
  ///
  /// In en, this message translates to:
  /// **'{level} and up'**
  String logLevelAndUp(String level);

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get upNext;

  /// No description provided for @upNextIn.
  ///
  /// In en, this message translates to:
  /// **'Playing in {seconds} s'**
  String upNextIn(int seconds);

  /// No description provided for @upNextPlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get upNextPlayNow;

  /// No description provided for @upNextCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get upNextCancel;

  /// No description provided for @onThisPhone.
  ///
  /// In en, this message translates to:
  /// **'ON THIS PHONE'**
  String get onThisPhone;

  /// No description provided for @showPhoneVideos.
  ///
  /// In en, this message translates to:
  /// **'Show videos on this phone'**
  String get showPhoneVideos;

  /// No description provided for @phoneVideosDenied.
  ///
  /// In en, this message translates to:
  /// **'Kyndrel needs permission to list your videos.'**
  String get phoneVideosDenied;

  /// No description provided for @phoneVideosNone.
  ///
  /// In en, this message translates to:
  /// **'No videos on this phone yet.'**
  String get phoneVideosNone;

  /// No description provided for @allFolders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFolders;

  /// No description provided for @settingsGestures.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get settingsGestures;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get moreQueue;

  /// No description provided for @morePicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get morePicture;

  /// No description provided for @moreTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get moreTranslate;

  /// No description provided for @moreSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed & sleep'**
  String get moreSpeed;

  /// No description provided for @moreCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get moreCast;

  /// No description provided for @moreDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get moreDownload;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @morePip.
  ///
  /// In en, this message translates to:
  /// **'Small window'**
  String get morePip;

  /// No description provided for @subtitleNotShown.
  ///
  /// In en, this message translates to:
  /// **'This subtitle track can\'t be shown'**
  String get subtitleNotShown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
