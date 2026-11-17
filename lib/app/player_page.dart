import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/engine_sync.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/player_shortcuts.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/window/window_title_bar.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_video_view.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/features/info/media_info_dialog.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';
import 'package:kyndrel/features/playback/resume/resume_banner.dart';
import 'package:kyndrel/features/playback/resume/resume_controller.dart';
import 'package:kyndrel/features/playback/widgets/bottom_controls.dart';
import 'package:kyndrel/features/playback/widgets/diagnostics_overlay.dart';
import 'package:kyndrel/features/playback/widgets/fit_menu.dart';
import 'package:kyndrel/features/playback/widgets/fullscreen_button.dart';
import 'package:kyndrel/features/playback/widgets/status_layer.dart';
import 'package:kyndrel/features/playback/widgets/top_bar.dart';
import 'package:kyndrel/features/playback/widgets/video_gesture_layer.dart';
import 'package:kyndrel/features/settings/settings_dialog.dart';
import 'package:kyndrel/features/speed_sleep/speed_sleep_button.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
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
    ref.read(engineSyncProvider);
    final resume = ref.read(resumeControllerProvider.notifier);
    ref.read(windowServiceProvider).onClose(resume.saveNow);

    final source = widget.launch.source;
    if (source != null) {
      unawaited(ref.read(playerServiceProvider).open(source));
    }
    PlayerPage.openFileChannel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        await ref.read(playerServiceProvider).open(call.arguments as String);
      }
    });
    unawaited(_openPendingMacFiles());
  }

  Future<void> _openPendingMacFiles() async {
    try {
      final files = await PlayerPage.openFileChannel.invokeListMethod<String>(
        'pending',
      );
      if (files != null && files.isNotEmpty && mounted) {
        await ref.read(playerServiceProvider).open(files.first);
      }
    } on MissingPluginException {
      // Only macOS implements the channel.
    }
  }

  @override
  void dispose() {
    PlayerPage.openFileChannel.setMethodCallHandler(null);
    super.dispose();
  }

  void _pickFile() => unawaited(OpenActions.pickFile(ref));
  void _showInfo() => unawaited(showMediaInfoDialog(context, ref));
  void _showSettings() => unawaited(showSettingsDialog(context));

  Future<void> _contextMenu(Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: KyndrelColors.surface,
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open file…')),
        PopupMenuItem(value: 'paste', child: Text('Open from clipboard')),
        PopupMenuItem(value: 'info', child: Text('Media info')),
        PopupMenuItem(value: 'subs', child: Text('Subtitles & audio')),
        PopupMenuItem(value: 'settings', child: Text('Settings…')),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'open':
        _pickFile();
      case 'paste':
        unawaited(OpenActions.pasteFromClipboard(ref));
      case 'info':
        _showInfo();
      case 'subs':
        ref.read(subtitlePanelProvider.notifier).open();
      case 'settings':
        _showSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(resumeControllerProvider)
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
    final hasMedia = !idle && status != PlaybackStatus.error;

    Widget fade(Widget child) => IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );

    return Scaffold(
      backgroundColor: KyndrelColors.background,
      body: PlayerShortcuts(
        onOpenSettings: _showSettings,
        onShowInfo: _showInfo,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            if (details.files.isNotEmpty) {
              unawaited(
                ref.read(playerServiceProvider).open(details.files.first.path),
              );
            }
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
                const PlayerVideoView(),
                if (hasMedia) VideoGestureLayer(onSecondaryTap: _contextMenu),
                StatusLayer(onPickFile: _pickFile),
                const Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(child: OsdView()),
                ),
                if (widget.launch.showDiagnostics)
                  const Positioned(
                    top: 56,
                    right: 12,
                    child: DiagnosticsOverlay(),
                  ),
                const Positioned(
                  bottom: 150,
                  left: 0,
                  right: 0,
                  child: Center(child: ResumeBanner()),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: fade(
                    WindowTitleBar(
                      showButtons: !fullScreen,
                      child: TopBarContent(
                        onBack: () =>
                            unawaited(ref.read(playerServiceProvider).close()),
                        onInfo: _showInfo,
                      ),
                    ),
                  ),
                ),
                if (hasMedia)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: fade(
                      const BottomControls(
                        rightActions: [
                          FitMenuButton(),
                          ControlButton(
                            key: Key('translate'),
                            icon: Icons.translate,
                            tooltip:
                                'Translate subtitles (coming in a later '
                                'version)',
                          ),
                          SubtitlesButton(),
                          SpeedSleepButton(),
                          ControlButton(
                            key: Key('pip'),
                            icon: Icons.picture_in_picture_alt,
                            tooltip:
                                'Picture in picture (coming in a later '
                                'version)',
                          ),
                          ControlButton(
                            key: Key('cast'),
                            icon: Icons.cast,
                            tooltip: 'Cast (coming in a later version)',
                          ),
                          FullscreenButton(),
                        ],
                      ),
                    ),
                  ),
                if (panelOpen && hasMedia)
                  const Positioned(
                    right: 20,
                    bottom: 130,
                    child: SubtitlePanel(),
                  ),
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
        child: const Text(
          'Drop to play',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
