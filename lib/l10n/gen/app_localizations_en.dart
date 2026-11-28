// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get playTooltip => 'Play (Space)';

  @override
  String get pauseTooltip => 'Pause (Space)';

  @override
  String get previousTooltip => 'Previous (P)';

  @override
  String get nextTooltip => 'Next (N)';

  @override
  String backSeconds(int seconds) {
    return 'Back $seconds s';
  }

  @override
  String forwardSeconds(int seconds) {
    return 'Forward $seconds s';
  }

  @override
  String get muteTooltip => 'Mute (M)';

  @override
  String get unmuteTooltip => 'Unmute (M)';

  @override
  String get volumeMuted => 'Muted';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String endsAt(String time) {
    return 'Ends at $time';
  }

  @override
  String get volume => 'Volume';

  @override
  String get fullscreenTooltip => 'Full screen (F)';

  @override
  String get exitFullscreenTooltip => 'Exit full screen (F)';

  @override
  String get showTotalTime => 'Show total time';

  @override
  String get showRemainingTime => 'Show remaining time';

  @override
  String get live => 'LIVE';

  @override
  String get back => 'Back';

  @override
  String get mediaInfo => 'Media info';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get close => 'Close';

  @override
  String get closeEsc => 'Close (Esc)';

  @override
  String get copyLog => 'Copy log';

  @override
  String get fitAndAspect => 'Fit & aspect';

  @override
  String get fitHeader => 'FIT';

  @override
  String get zoomHeader => 'ZOOM';

  @override
  String get rotateHeader => 'ROTATE';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get rotateClockwise => 'Rotate 90° clockwise';

  @override
  String get reset => 'Reset';

  @override
  String get openMediaHeader => 'OPEN MEDIA';

  @override
  String get openFileShortcut => 'Open file…  (Ctrl+O)';

  @override
  String get pastePathOrUrl => 'Paste a path or URL';

  @override
  String get open => 'Open';

  @override
  String get dropHint =>
      'Or drop a file anywhere in the window. Ctrl+N opens streams, shares and WebDAV folders.';

  @override
  String resumeFrom(String time) {
    return 'Resume from $time?';
  }

  @override
  String get startOver => 'Start over';

  @override
  String get resume => 'Resume';

  @override
  String get speedAndSleep => 'Speed & sleep';

  @override
  String speedOsd(String rate) {
    return 'Speed $rate';
  }

  @override
  String get playbackSpeedHeader => 'PLAYBACK SPEED';

  @override
  String get sleepTimerHeader => 'SLEEP TIMER';

  @override
  String get sleepCancelHint => 'Choose the same option again to cancel.';

  @override
  String get defaultBadge => 'DEFAULT';

  @override
  String get custom => 'Custom';

  @override
  String get apply => 'Apply';

  @override
  String get queueTooltip => 'Queue (Q)';

  @override
  String queueCountTooltip(int count) {
    return 'Queue · $count (Q)';
  }

  @override
  String queueTitle(int count) {
    return 'Queue · $count';
  }

  @override
  String get shuffleOn => 'Shuffle on';

  @override
  String get shuffleOff => 'Shuffle off';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAll => 'Repeat all';

  @override
  String get repeatOne => 'Repeat one';

  @override
  String get queueEmpty => 'The queue is empty.';

  @override
  String get clear => 'Clear';

  @override
  String get folder => 'Folder';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get continueWatching => 'CONTINUE WATCHING';

  @override
  String get recent => 'RECENT';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get removeFromHistory => 'Remove from history';

  @override
  String get justNow => 'Just now';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get menuOpenFile => 'Open file…';

  @override
  String get menuOpenFolder => 'Open folder…';

  @override
  String get menuOpenClipboard => 'Open from clipboard';

  @override
  String get menuOpenStream => 'Open network stream…';

  @override
  String get menuEditDetails => 'Edit details…';

  @override
  String get menuScreenshot => 'Screenshot  (Ctrl+S)';

  @override
  String get menuSubtitlesAudio => 'Subtitles & audio';

  @override
  String get menuEffects => 'Video & audio effects…';

  @override
  String get menuSettings => 'Settings…';

  @override
  String get dropToPlay => 'Drop to play';

  @override
  String get subtitlesAudioTooltip => 'Subtitles & audio (S)';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesHeader => 'SUBTITLES';

  @override
  String get audioHeader => 'AUDIO';

  @override
  String get syncOffset => 'Sync offset';

  @override
  String get style => 'Style';

  @override
  String get off => 'Off';

  @override
  String get subtitleSearchHint => 'Title, or \"Show S01E02\"';

  @override
  String get search => 'Search';

  @override
  String get findMoreSubtitles => 'Find more subtitles';

  @override
  String get loadFile => 'Load file';

  @override
  String get settings => 'Settings';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsSubtitles => 'Subtitles';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsEffects => 'Effects';

  @override
  String get settingsVideo => 'Video';

  @override
  String get settingsPicture => 'Picture';

  @override
  String get settingsShortcuts => 'Shortcuts';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsAbout => 'About';

  @override
  String get languageSystem => 'System';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String get diagnosticsHeader => 'DIAGNOSTICS';

  @override
  String hardwareDecoding(String hwdec) {
    return 'Hardware decoding: $hwdec';
  }

  @override
  String get softwareDecoding => 'Software decoding';

  @override
  String get seekLabel => 'Seek';

  @override
  String seekValue(String elapsed, String total) {
    return '$elapsed of $total';
  }

  @override
  String get videoSurface => 'Video';

  @override
  String get videoSurfaceHint =>
      'Tap to show controls, double-tap for full screen';

  @override
  String updateAvailable(String version) {
    return 'Kyndrel $version is available';
  }

  @override
  String get updateInstall => 'Install and restart';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updateLater => 'Later';

  @override
  String updateDownloading(int percent) {
    return 'Downloading update… $percent %';
  }

  @override
  String get updateUpToDate => 'Kyndrel is up to date.';

  @override
  String updateFailed(String reason) {
    return 'Could not check for updates: $reason';
  }

  @override
  String get updateCheckNow => 'Check for updates';

  @override
  String get crashTitle => 'Kyndrel stopped unexpectedly';

  @override
  String get crashBodyExit =>
      'The last session ended without closing normally. Would you like to report it? This opens a GitHub issue in your browser with the version, your OS and the end of the log filled in. You can edit or discard it before sending.';

  @override
  String get crashBodyError =>
      'Something went wrong in the last session. Would you like to report it? This opens a pre-filled GitHub issue in your browser; nothing is sent unless you submit it.';

  @override
  String get crashReport => 'Report on GitHub';

  @override
  String get notNow => 'Not now';

  @override
  String get viewLog => 'View log';

  @override
  String get logTitle => 'Log';

  @override
  String get logCopy => 'Copy';

  @override
  String get logCopied => 'Log copied';

  @override
  String get logOpenFolder => 'Open log folder';

  @override
  String get logEmpty => 'Nothing logged yet.';

  @override
  String logLevelAndUp(String level) {
    return '$level and up';
  }

  @override
  String get upNext => 'UP NEXT';

  @override
  String upNextIn(int seconds) {
    return 'Playing in $seconds s';
  }

  @override
  String get upNextPlayNow => 'Play now';

  @override
  String get upNextCancel => 'Cancel';

  @override
  String get onThisPhone => 'ON THIS PHONE';

  @override
  String get showPhoneVideos => 'Show videos on this phone';

  @override
  String get phoneVideosDenied =>
      'Kyndrel needs permission to list your videos.';

  @override
  String get phoneVideosNone => 'No videos on this phone yet.';

  @override
  String get allFolders => 'All';

  @override
  String get settingsGestures => 'Gestures';

  @override
  String get more => 'More';

  @override
  String get moreQueue => 'Queue';

  @override
  String get morePicture => 'Picture';

  @override
  String get moreTranslate => 'Translate';

  @override
  String get moreSpeed => 'Speed & sleep';

  @override
  String get moreCast => 'Cast';

  @override
  String get moreDownload => 'Download';

  @override
  String get rotate => 'Rotate';

  @override
  String get morePip => 'Small window';

  @override
  String get subtitleNotShown => 'This subtitle track can\'t be shown';

  @override
  String get libraryHome => 'Home';

  @override
  String get libraryVideos => 'Videos';

  @override
  String get libraryMusic => 'Music';

  @override
  String get libraryFolders => 'Folders';

  @override
  String get libraryAllVideos => 'All videos';

  @override
  String get librarySearch => 'Search';

  @override
  String get librarySort => 'Sort';

  @override
  String get sortDate => 'Date added';

  @override
  String get sortName => 'Name';

  @override
  String get sortSize => 'Size';

  @override
  String get sortLength => 'Length';

  @override
  String get layoutList => 'List';

  @override
  String get layoutGrid => 'Grid';

  @override
  String get libraryRefresh => 'Refresh';

  @override
  String get libraryEmptyVideos => 'No videos found yet';

  @override
  String get libraryNoMatch => 'Nothing matches your search';

  @override
  String get libraryAllowTitle => 'See the videos and music on this phone';

  @override
  String get libraryAllow => 'Allow access';

  @override
  String get libraryScanning => 'Looking for videos and music…';

  @override
  String get libraryManageFolders => 'Library folders';

  @override
  String get libraryAddFolder => 'Add folder';

  @override
  String get libraryRemoveFolder => 'Remove';

  @override
  String get libraryDefaultFolders =>
      'Your Videos and Music folders are used until you add your own.';

  @override
  String get libraryNew => 'NEW';

  @override
  String get libraryPlay => 'Play';

  @override
  String get libraryEnqueue => 'Add to queue';

  @override
  String get libraryOpenFolder => 'Show in folder';

  @override
  String get libraryDetails => 'Details';

  @override
  String get detailFolder => 'Folder';

  @override
  String get detailLength => 'Length';

  @override
  String get detailResolution => 'Resolution';

  @override
  String get detailVideo => 'Video';

  @override
  String get detailAudio => 'Audio';

  @override
  String get detailSize => 'Size';

  @override
  String get detailModified => 'Modified';

  @override
  String get detailAdded => 'Added';

  @override
  String get detailWatched => 'Watched';

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get musicSongs => 'Songs';

  @override
  String get musicAlbums => 'Albums';

  @override
  String get musicArtists => 'Artists';

  @override
  String get musicShuffle => 'Shuffle all';

  @override
  String get musicPlayAll => 'Play all';

  @override
  String get unknownAlbum => 'Unknown album';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get libraryEmptyMusic => 'No music found yet';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get musicMinimize => 'Back to the library';

  @override
  String get musicNext => 'Next';

  @override
  String get settingsMusic => 'MUSIC';

  @override
  String get musicWavesSetting => 'Waves that follow the music';

  @override
  String get musicWavesHelp =>
      'Orange waves under the record move with the loudness.';

  @override
  String get reduceMotionSetting => 'Less motion';

  @override
  String get reduceMotionHelp =>
      'The record stays still and the waves move gently.';

  @override
  String get libraryViewRecent => 'Recently added';

  @override
  String get libraryViewPlaylists => 'Playlists';

  @override
  String get libraryContinue => 'Continue watching';

  @override
  String librarySelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get librarySelectAll => 'Select all';

  @override
  String get libraryAddToPlaylist => 'Add to playlist';

  @override
  String get libraryNewPlaylist => 'New playlist';

  @override
  String get libraryPlaylistName => 'Playlist name';

  @override
  String get libraryRename => 'Rename';

  @override
  String get libraryDelete => 'Delete';

  @override
  String libraryDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count files to the trash?',
      one: 'Move this file to the trash?',
    );
    return '$_temp0';
  }

  @override
  String get libraryMove => 'Move to…';

  @override
  String get libraryShare => 'Share';

  @override
  String get libraryMarkWatched => 'Mark as watched';

  @override
  String get libraryMarkUnwatched => 'Mark as unwatched';

  @override
  String get libraryPin => 'Pin to top';

  @override
  String get libraryUnpin => 'Unpin';

  @override
  String get libraryHide => 'Hide folder';

  @override
  String get libraryUnhide => 'Show folder';

  @override
  String get libraryShowHidden => 'Show hidden folders';

  @override
  String get libraryMakePrivate => 'Make private';

  @override
  String get libraryMakePublic => 'Remove from private';

  @override
  String get libraryPrivate => 'Private folders';

  @override
  String get libraryLock => 'Lock private folders';

  @override
  String get libraryPinTitle => 'Enter your PIN';

  @override
  String get librarySetPin => 'Choose a PIN (4–8 digits)';

  @override
  String get libraryWrongPin => 'Wrong PIN';

  @override
  String get libraryPlayAll => 'Play all';

  @override
  String get libraryShuffle => 'Shuffle';

  @override
  String get libraryDescending => 'Newest / largest first';

  @override
  String get layoutCompact => 'Compact';

  @override
  String get libraryGridSmall => 'Small grid';

  @override
  String get libraryGridLarge => 'Large grid';

  @override
  String get libraryFilterUnwatched => 'Unwatched only';

  @override
  String get libraryFilterHd => 'HD and above';

  @override
  String get libraryFilterSubtitles => 'With subtitles';

  @override
  String get libraryLastPlayed => 'Last played';

  @override
  String get libraryPlaylistEmpty =>
      'No playlists yet. Select videos and add them to one.';

  @override
  String get librarySmartUnwatched => 'Unwatched videos';

  @override
  String get librarySmartRecent => 'Added this month';

  @override
  String libraryActionFailed(String name) {
    return 'Couldn\'t do that: $name';
  }

  @override
  String get playlistRename => 'Rename playlist';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String get playlistRemove => 'Remove from playlist';

  @override
  String get libraryFilters => 'Filters';

  @override
  String get libraryFolderActions => 'Folder';

  @override
  String get libraryBrowse => 'Browse';

  @override
  String get browseDevice => 'This device';

  @override
  String get browseNetwork => 'Network';

  @override
  String get browseHome => 'Home folder';

  @override
  String get browseRoot => 'Whole disk';

  @override
  String get browseAddServer => 'Add server';

  @override
  String get browseServerKind => 'Type';

  @override
  String get browseServerName => 'Name';

  @override
  String get browseServerAddress => 'Address';

  @override
  String get browseUser => 'User name (optional)';

  @override
  String get browsePassword => 'Password';

  @override
  String get browseSave => 'Save';

  @override
  String get browseRemove => 'Remove server';

  @override
  String get browseSearching => 'Looking for media servers…';

  @override
  String get browseNoServers => 'No media servers found on this network.';

  @override
  String get browseEmpty => 'No folders or playable files here.';

  @override
  String browseFailed(String reason) {
    return 'Couldn\'t open this folder: $reason';
  }

  @override
  String get browseOpenOnly =>
      'This kind of server can\'t be listed: its files open by address.';

  @override
  String get browseFind => 'Find in this folder';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarksEmpty =>
      'No bookmarks yet. Press B to add one where you are.';

  @override
  String get bookmarkAdd => 'Bookmark here';

  @override
  String get jumpToTime => 'Jump to time';

  @override
  String get jumpToTimeHint => '1:23:45, 83:10, 90 or 50%';

  @override
  String get decoderTooltip =>
      'Decoding: hardware, hardware with copy, or software';

  @override
  String get loadAudioFile => 'Load audio file';

  @override
  String get libraryForget => 'Remove from history';

  @override
  String get subtitleLines => 'Subtitle lines';

  @override
  String get subtitleLinesUnavailable =>
      'Lines can be listed for subtitle files. Load one, or pick a file track.';

  @override
  String get copy => 'Copy';

  @override
  String get quickCommands => 'Quick commands';

  @override
  String get quickCommandsEmpty =>
      'No quick commands yet. Add them in Settings › Advanced.';

  @override
  String get skipIntro => 'Skip intro';

  @override
  String get skipCredits => 'Skip credits';

  @override
  String get nextEpisode => 'Next episode';

  @override
  String get homeSearchHint => 'Search your videos';

  @override
  String get homeResume => 'Resume';

  @override
  String get homeStartOver => 'Start over';

  @override
  String get homeContinueTitle => 'Continue Watching';

  @override
  String get homeRecentlyAdded => 'Recently Added';

  @override
  String get homeHistory => 'History';

  @override
  String get homeOpenTitle => 'Play anything';

  @override
  String get homeOpenSubtitle =>
      'Open a file or paste a link. Your videos appear here as you watch.';

  @override
  String homeLeft(String time) {
    return '$time left';
  }

  @override
  String get homeChip => 'Continue watching';

  @override
  String get settingsTogether => 'Watch together';
}
