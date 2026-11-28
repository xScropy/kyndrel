import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/engine_sync.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/log_sync.dart';
import 'package:kyndrel/app/media_session_sync.dart';
import 'package:kyndrel/app/memory_guard.dart';
import 'package:kyndrel/app/perf_log.dart';
import 'package:kyndrel/app/player_shortcuts.dart';
import 'package:kyndrel/app/settings_page.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/window/window_title_bar.dart';
import 'package:kyndrel/core/platform/native_pip.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/library_previews.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_video_view.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/ui/volume_hud.dart';
import 'package:kyndrel/features/browse/browse_view.dart';
import 'package:kyndrel/features/cast/cast_button.dart';
import 'package:kyndrel/features/download/download_button.dart';
import 'package:kyndrel/features/effects/effects_dialog.dart';
import 'package:kyndrel/features/info/media_info_dialog.dart';
import 'package:kyndrel/features/library/edit_details_dialog.dart';
import 'package:kyndrel/features/library/history_controller.dart';
import 'package:kyndrel/features/library/library_home.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:kyndrel/features/library/playlist_panel.dart';
import 'package:kyndrel/features/library/up_next_card.dart';
import 'package:kyndrel/features/logs/crash_prompt.dart';
import 'package:kyndrel/features/music/music_player_view.dart';
import 'package:kyndrel/features/music/now_playing.dart';
import 'package:kyndrel/features/network/open_url_dialog.dart';
import 'package:kyndrel/features/pip/pip_controller.dart';
import 'package:kyndrel/features/pip/pip_view.dart';
import 'package:kyndrel/features/playback/file_settings_controller.dart';
import 'package:kyndrel/features/playback/gesture_lock.dart';
import 'package:kyndrel/features/playback/heatmap.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';
import 'package:kyndrel/features/playback/phone_playback.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:kyndrel/features/playback/resume/resume_banner.dart';
import 'package:kyndrel/features/playback/resume/resume_controller.dart';
import 'package:kyndrel/features/playback/screenshot_actions.dart';
import 'package:kyndrel/features/playback/skip_intro.dart';
import 'package:kyndrel/features/playback/widgets/bottom_controls.dart';
import 'package:kyndrel/features/playback/widgets/diagnostics_overlay.dart';
import 'package:kyndrel/features/playback/widgets/fit_menu.dart';
import 'package:kyndrel/features/playback/widgets/fullscreen_button.dart';
import 'package:kyndrel/features/playback/widgets/more_sheet.dart';
import 'package:kyndrel/features/playback/widgets/open_source_prompt.dart';
import 'package:kyndrel/features/playback/widgets/status_layer.dart';
import 'package:kyndrel/features/playback/widgets/swipe_seek_preview.dart';
import 'package:kyndrel/features/playback/widgets/top_bar.dart';
import 'package:kyndrel/features/playback/widgets/video_gesture_layer.dart';
import 'package:kyndrel/features/scripts/script_manager.dart';
import 'package:kyndrel/features/speed_sleep/speed_sleep_button.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:kyndrel/features/translate/translate_button.dart';
import 'package:kyndrel/features/update/update_banner.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The player screen: composes the features (the only place that may import
/// several of them) into the layout from the reference screenshots.
class PlayerPage extends ConsumerStatefulWidget {
  const new({this.launch = const LaunchOptions(), super.key});

  final LaunchOptions launch;

  /// "Open with" on macOS arrives here (see `macos/Runner/AppDelegate.swift`).
  static const openFileChannel = MethodChannel('kyndrel/open_file');

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    ref
      ..read(engineSyncProvider)
      // "No sound" instead of silence when the device fails.
      ..read(audioProblemNoticeProvider)
      // Image-cache cap, and closing the frame engine when memory is short.
      ..read(memoryGuardProvider)
      ..read(mediaSessionSyncProvider)
      ..read(scriptManagerProvider)
      ..read(logSyncProvider)
      // Frames for the whole video, made in the background (task 7.2).
      ..read(storyboardProvider)
      // Library videos' coarse storyboards, made while idle (task 8.4).
      ..read(libraryPreviewsProvider)
      // Each file's tracks, speed, delays and picture (task 8.8).
      ..read(fileSettingsControllerProvider)
      // Openings and credits to skip (task 8.9).
      ..read(skipIntroProvider)
      // What gets watched again, for the seek bar's heatmap (task 8.10).
      ..read(replayRecorderProvider)
      // Music: tags, cover and the level meter (task 7.6).
      ..read(nowPlayingProvider);
    // Phones: immersive full screen and rotation while a video plays.
    if (ref.read(platformCapabilitiesProvider).isMobile) {
      ref.read(phonePlaybackProvider);
    }
    PerfLog.start(ref);
    final resume = ref.read(resumeControllerProvider.notifier);
    final history = ref.read(historyControllerProvider.notifier);
    ref.read(windowServiceProvider)
      ..onClose(resume.saveNow)
      ..onClose(history.saveNow)
      // Android may end the process in the background: save on the way.
      ..onHidden(resume.saveNow)
      ..onHidden(history.saveNow)
      ..onHidden(_pauseInBackground)
      ..onShown(_backInForeground)
      // Last: release libmpv and the video texture before the window is
      // destroyed. On Linux, destroying the GTK window with a live texture
      // aborts the process (g_mutex_clear on a locked mutex).
      ..onClose(ref.read(playerServiceProvider).dispose);

    final source = widget.launch.source;
    if (source != null) {
      // The queue is provider state: change it after the first frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(OpenActions.openSource(ref, source)),
      );
    }
    PlayerPage.openFileChannel.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        await OpenActions.openFromSystem(ref, call.arguments);
      }
    });
    unawaited(_openPendingSystemFiles());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(maybeOfferCrashReport(context, ref));
    });
  }

  Future<void> _openPendingSystemFiles() async {
    try {
      final files = await PlayerPage.openFileChannel.invokeListMethod<Object?>(
        'pending',
      );
      if (files != null && files.isNotEmpty && mounted) {
        await OpenActions.openFromSystem(ref, files);
      }
    } on MissingPluginException {
      // Only macOS and Android implement the channel.
    }
  }

  /// Phones (task 6.6): leaving the app pauses, unless the sound should go
  /// on in the background or the video went into picture-in-picture.
  /// Playing on in the background decodes only the sound (task 6.7).
  Future<void> _pauseInBackground() async {
    if (ref.read(pipProvider)) return;
    final service = ref.read(playerServiceProvider);
    if (ref.read(settingsProvider).backgroundAudio) {
      await service.setVideoDecoding(enabled: false);
    } else {
      await service.pause();
    }
  }

  Future<void> _backInForeground() =>
      ref.read(playerServiceProvider).setVideoDecoding(enabled: true);

  @override
  void dispose() {
    PlayerPage.openFileChannel.setMethodCallHandler(null);
    super.dispose();
  }

  void _pickFile() => unawaited(OpenActions.pickFile(ref));
  void _showInfo() => unawaited(showMediaInfoDialog(context, ref));
  void _showSettings() => unawaited(showSettingsPage(context));

  /// Phones: at most 75 % of the screen's height for a panel.
  static Widget _panelBox({
    required bool compact,
    required Size screen,
    required Widget child,
  }) => compact
      ? ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screen.height * 0.75),
          child: child,
        )
      : child;

  /// The phone's "More" sheet (task 6.5).
  List<MoreAction> _moreActions(BuildContext context) {
    final l = context.l10n;
    return [
      (button: const PlaylistButton(), label: l.moreQueue),
      (button: const FitMenuButton(), label: l.morePicture),
      (button: const SpeedSleepButton(), label: l.moreSpeed),
      (button: const TranslateButton(), label: l.moreTranslate),
      (button: const CastButton(), label: l.moreCast),
      (button: const DownloadButton(), label: l.moreDownload),
      if (ref.read(nativePipProvider) != null)
        (button: const PipButton(), label: l.morePip),
    ];
  }

  Future<void> _contextMenu(Offset position) async {
    final l = context.l10n;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: KyndrelColors.surface,
      items: [
        PopupMenuItem(value: 'open', child: Text(l.menuOpenFile)),
        PopupMenuItem(value: 'folder', child: Text(l.menuOpenFolder)),
        PopupMenuItem(value: 'paste', child: Text(l.menuOpenClipboard)),
        PopupMenuItem(value: 'url', child: Text(l.menuOpenStream)),
        PopupMenuItem(value: 'info', child: Text(l.mediaInfo)),
        PopupMenuItem(value: 'details', child: Text(l.menuEditDetails)),
        PopupMenuItem(value: 'screenshot', child: Text(l.menuScreenshot)),
        PopupMenuItem(value: 'subs', child: Text(l.menuSubtitlesAudio)),
        PopupMenuItem(value: 'effects', child: Text(l.menuEffects)),
        PopupMenuItem(value: 'settings', child: Text(l.menuSettings)),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'open':
        _pickFile();
      case 'folder':
        unawaited(OpenActions.pickFolder(ref));
      case 'paste':
        unawaited(OpenActions.pasteFromClipboard(ref));
      case 'url':
        unawaited(showOpenUrlDialog(context));
      case 'info':
        _showInfo();
      case 'screenshot':
        unawaited(ScreenshotActions.take(ref));
      case 'details':
        final source = ref.read(playerServiceProvider).state.source;
        if (source != null) unawaited(showEditDetailsDialog(context, source));
      case 'effects':
        unawaited(showEffectsDialog(context));
      case 'subs':
        ref.read(subtitlePanelProvider.notifier).open();
      case 'settings':
        _showSettings();
    }
  }

  /// The library's Home section around [prompt].
  Widget _home(Widget prompt) => LibraryHome(
    openPrompt: prompt,
    onOpen: (s) => unawaited(OpenActions.openSource(ref, s)),
    onResume: (s) {
      ref.read(resumeControllerProvider.notifier).resumeNextLoadOf(s);
      unawaited(ref.read(playlistProvider.notifier).open(s));
    },
  );

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(resumeControllerProvider)
      ..watch(historyControllerProvider)
      ..listen(playbackStatusProvider, (_, next) {
        ref
            .read(controlsVisibilityProvider.notifier)
            .setAutoHide(enabled: next.value == PlaybackStatus.playing);
      });

    final status =
        ref.watch(playbackStatusProvider).value ?? PlaybackStatus.idle;
    final idle = status == PlaybackStatus.idle;
    final visible = ref.watch(controlsVisibilityProvider) || idle;
    final fullScreen = ref.watch(isFullScreenProvider).value ?? false;
    final panelOpen = ref.watch(subtitlePanelProvider) != null;
    final queueOpen = ref.watch(playlistPanelProvider);
    final hasMedia = !idle && status != PlaybackStatus.error;
    final mobile = ref.watch(platformCapabilitiesProvider).isMobile;
    // Phone layout (task 6.5): phones, and narrow desktop windows.
    final screen = MediaQuery.sizeOf(context);
    final compact = mobile || screen.width < 600;
    // Screen lock (task 6.3): no controls, no gestures until unlocked.
    final locked = hasMedia && ref.watch(gestureLockProvider);
    // Music (task 7.6): the record view, or the library with a mini player.
    final audioOnly =
        hasMedia &&
        ref.watch(
          trackStateProvider.select((t) => t.value?.isAudioOnly ?? false),
        );
    if (audioOnly && ref.watch(musicMinimizedProvider)) {
      return Scaffold(
        backgroundColor: KyndrelColors.background,
        body: PlayerShortcuts(
          onOpenSettings: _showSettings,
          onShowInfo: _showInfo,
          onToggleQueue: ref.read(playlistPanelProvider.notifier).toggle,
          child: SafeArea(
            bottom: false,
            child: LibraryShell(
              topInset: 0,
              browse: const BrowseView(),
              home: _home(
                OpenSourcePrompt(
                  onOpen: ref.read(playlistProvider.notifier).open,
                  onPickFile: _pickFile,
                ),
              ),
              bottom: const MiniPlayer(),
            ),
          ),
        ),
      );
    }
    if (ref.watch(pipProvider) && ref.watch(nativePipProvider) != null) {
      // Android's PiP window: just the picture; Android draws the buttons.
      return const Scaffold(
        backgroundColor: KyndrelColors.background,
        body: PlayerVideoView(),
      );
    }
    if (ref.watch(pipProvider)) {
      return Scaffold(
        backgroundColor: KyndrelColors.background,
        body: PlayerShortcuts(
          onOpenSettings: () {},
          onShowInfo: () {},
          onToggleQueue: () {},
          child: const PipView(video: PlayerVideoView()),
        ),
      );
    }

    Widget fade(Widget child) => KeyboardFocusKeepsControls(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: RepaintBoundary(child: child),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: KyndrelColors.background,
      body: PlayerShortcuts(
        onOpenSettings: _showSettings,
        onShowInfo: _showInfo,
        onToggleQueue: ref.read(playlistPanelProvider.notifier).toggle,
        onOpenUrl: () => unawaited(showOpenUrlDialog(context)),
        onEffects: () => unawaited(showEffectsDialog(context)),
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            unawaited(
              OpenActions.openPaths(
                ref,
                details.files.map((f) => f.path).toList(),
              ),
            );
          },
          child: MouseRegion(
            cursor: !visible && fullScreen
                ? SystemMouseCursors.none
                : MouseCursor.defer,
            onHover: (_) =>
                ref.read(controlsVisibilityProvider.notifier).show(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Own layer: overlay fades, OSD and seek-bar ticks must not
                // repaint the video (task 5.4).
                RepaintBoundary(
                  key: const Key('video-layer'),
                  child: audioOnly
                      ? const MusicPlayerView()
                      : const PlayerVideoView(),
                ),
                // Music has its own buttons; there's no picture to touch.
                if (hasMedia && !audioOnly)
                  VideoGestureLayer(onSecondaryTap: _contextMenu),
                StatusLayer(
                  onPickFile: _pickFile,
                  // Home and the device's library (task 7.4).
                  idle: (prompt) => LibraryShell(
                    home: _home(prompt),
                    // Folders and network servers (task 8.7).
                    browse: const BrowseView(),
                  ),
                ),
                const Center(child: CastingBanner()),
                const Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(child: OsdView()),
                ),
                // Brightness/volume level while swiping (task 6.3).
                const Center(child: LevelOsdView()),
                // Harbor's volume panel for keys, wheel and mute (9.1).
                const Positioned(
                  top: 36,
                  left: 0,
                  right: 0,
                  child: Center(child: VolumeHud()),
                ),
                // The scene under the finger while swipe-seeking (6.4).
                const Center(child: SwipeSeekPreview()),
                const Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Center(child: UpdateBanner()),
                ),
                const PositionedDirectional(
                  end: 20,
                  bottom: 130,
                  child: UpNextCard(),
                ),
                // "Skip intro" / "Next episode" (task 8.9).
                const PositionedDirectional(
                  end: 24,
                  bottom: 140,
                  child: SkipIntroButton(),
                ),
                if (widget.launch.showDiagnostics ||
                    ref.watch(statsOverlayProvider))
                  const PositionedDirectional(
                    top: 56,
                    end: 12,
                    child: DiagnosticsOverlay(),
                  ),
                const Positioned(
                  bottom: 150,
                  left: 0,
                  right: 0,
                  child: Center(child: ResumeBanner()),
                ),
                if (!locked)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: fade(
                      // Phones: keep clear of the notch and status bar.
                      SafeArea(
                        bottom: false,
                        child: WindowTitleBar(
                          showButtons: !fullScreen,
                          child: TopBarContent(
                            onBack: () => unawaited(
                              ref.read(playerServiceProvider).close(),
                            ),
                            onInfo: _showInfo,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (hasMedia && !locked)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: fade(
                      SafeArea(
                        top: false,
                        child: compact
                            ? BottomControls(
                                compact: true,
                                leftActions: [
                                  if (mobile) const LockButton(),
                                  const SubtitlesButton(),
                                ],
                                rightActions: [
                                  if (mobile)
                                    const RotateButton()
                                  else
                                    const FullscreenButton(),
                                  MoreButton(actions: _moreActions),
                                ],
                              )
                            : const BottomControls(
                                leftActions: [DownloadButton()],
                                rightActions: [
                                  PlaylistButton(),
                                  FitMenuButton(),
                                  TranslateButton(),
                                  SubtitlesButton(),
                                  SpeedSleepButton(),
                                  PipButton(),
                                  CastButton(),
                                  FullscreenButton(),
                                ],
                              ),
                      ),
                    ),
                  ),
                // Phones: panels span the width above the controls.
                if (panelOpen && hasMedia)
                  PositionedDirectional(
                    start: compact ? 8 : null,
                    end: compact ? 8 : 20,
                    bottom: compact ? 8 : 130,
                    child: _panelBox(
                      compact: compact,
                      screen: screen,
                      child: const SubtitlePanel(),
                    ),
                  ),
                if (queueOpen && hasMedia && !panelOpen)
                  PositionedDirectional(
                    start: compact ? 8 : null,
                    end: compact ? 8 : 20,
                    bottom: compact ? 8 : 130,
                    child: _panelBox(
                      compact: compact,
                      screen: screen,
                      child: PlaylistPanel(
                        onAddFiles: () =>
                            unawaited(OpenActions.pickToQueue(ref)),
                        onOpenFolder: () =>
                            unawaited(OpenActions.pickFolder(ref)),
                      ),
                    ),
                  ),
                if (locked) const Positioned.fill(child: LockedOverlay()),
                if (_dragging) const IgnorePointer(child: _DropHint()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropHint extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x99000000),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: KyndrelColors.accent, width: 2),
        ),
        child: Text(
          context.l10n.dropToPlay,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Keeps the overlay up while a control inside [child] has keyboard focus,
/// so Tab never lands on an invisible button (task 5.3). Mouse movement or
/// a click hands control back to the normal auto-hide.
class KeyboardFocusKeepsControls extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<KeyboardFocusKeepsControls> createState() =>
      _KeyboardFocusKeepsControlsState();
}

class _KeyboardFocusKeepsControlsState
    extends ConsumerState<KeyboardFocusKeepsControls> {
  bool _focused = false;
  bool _keyboard = false;
  bool _locked = false;
  late final ControlsVisibility _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(controlsVisibilityProvider.notifier);
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    if (_locked) _visibility.release(this);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && !_keyboard) {
      _keyboard = true;
      _sync();
    }
    return false;
  }

  void _onPointer(PointerEvent e) {
    if (_keyboard && (e is PointerDownEvent || e is PointerHoverEvent)) {
      _keyboard = false;
      _sync();
    }
  }

  void _sync() {
    final want = _focused && _keyboard;
    if (want == _locked || !mounted) return;
    _locked = want;
    if (want) {
      _visibility
        ..show()
        ..lock(this);
    } else {
      _visibility.unlock(this);
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (has) {
      _focused = has;
      _sync();
    },
    child: widget.child,
  );
}
