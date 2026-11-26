import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/key_bindings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/features/library/playlist_panel.dart';
import 'package:kyndrel/features/pip/pip_controller.dart';
import 'package:kyndrel/features/playback/clip_export.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';
import 'package:kyndrel/features/playback/player_tools.dart';
import 'package:kyndrel/features/playback/screenshot_actions.dart';
import 'package:kyndrel/features/playback/skip_intro.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:kyndrel/features/speed_sleep/speed_sleep_button.dart';
import 'package:kyndrel/features/subtitles/subtitle_lines.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Keyboard shortcuts (task 1.9); rebindable in Settings › Shortcuts
/// (task 5.1). Bindings live in `core/ui/key_bindings.dart`.
class PlayerShortcuts extends ConsumerWidget {
  const new({
    required this.child,
    required this.onOpenSettings,
    required this.onShowInfo,
    required this.onToggleQueue,
    this.onOpenUrl,
    this.onEffects,
    super.key,
  });

  final Widget child;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowInfo;
  final VoidCallback onToggleQueue;
  final VoidCallback? onOpenUrl;
  final VoidCallback? onEffects;

  /// True while a text field has focus, so typing isn't hijacked.
  static bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(BuildContext context, WidgetRef ref, KeyEvent event) {
    if (event is KeyUpEvent || _typing()) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final service = ref.read(playerServiceProvider);
    final playlist = ref.read(playlistProvider.notifier);
    final skip = Duration(seconds: ref.read(settingsProvider).skipSeconds);
    ref.read(controlsVisibilityProvider.notifier).show();

    // Media keys are fixed (elsewhere the OS media session delivers them).
    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlayPause:
        if (!repeat) unawaited(service.playOrPause());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaPlay:
        unawaited(service.play());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaPause || LogicalKeyboardKey.mediaStop:
        unawaited(service.pause());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaTrackNext:
        if (!repeat) unawaited(playlist.next());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaTrackPrevious:
        if (!repeat) unawaited(playlist.previous());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaFastForward:
        unawaited(service.seekBy(skip));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaRewind:
        unawaited(service.seekBy(-skip));
        return KeyEventResult.handled;
    }

    final combo = KeyCombo.fromEvent(event);
    final action = ref.read(settingsProvider).keyBindings.actionFor(combo);
    if (action == null) return KeyEventResult.ignored;
    if (repeat && !action.repeats) return KeyEventResult.handled;
    _run(context, ref, action, skip);
    return KeyEventResult.handled;
  }

  void _run(
    BuildContext context,
    WidgetRef ref,
    PlayerAction action,
    Duration skip,
  ) {
    final service = ref.read(playerServiceProvider);
    final playlist = ref.read(playlistProvider.notifier);
    final osd = ref.read(osdProvider.notifier);
    switch (action) {
      case PlayerAction.playPause:
        unawaited(service.playOrPause());
      case PlayerAction.seekBack:
        unawaited(service.seekBy(-skip));
        osd.show('−${skip.inSeconds} s');
      case PlayerAction.seekForward:
        unawaited(service.seekBy(skip));
        osd.show('+${skip.inSeconds} s');
      case PlayerAction.volumeUp:
        unawaited(VolumeActions.changeBy(ref, VolumeActions.step));
      case PlayerAction.volumeDown:
        unawaited(VolumeActions.changeBy(ref, -VolumeActions.step));
      case PlayerAction.mute:
        unawaited(VolumeActions.toggleMute(ref));
      case PlayerAction.fullscreen:
        unawaited(FullscreenActions.toggle(ref));
      case PlayerAction.back:
        if (ref.read(pipProvider)) {
          unawaited(ref.read(pipProvider.notifier).exit());
        } else if (ref.read(subtitlePanelProvider) != null) {
          ref.read(subtitlePanelProvider.notifier).close();
        } else if (ref.read(playlistPanelProvider)) {
          ref.read(playlistPanelProvider.notifier).close();
        } else {
          unawaited(FullscreenActions.exit(ref));
        }
      case PlayerAction.slower:
        unawaited(SpeedActions.stepDown(ref));
      case PlayerAction.faster:
        unawaited(SpeedActions.stepUp(ref));
      case PlayerAction.subtitles:
        ref.read(subtitlePanelProvider.notifier).toggle();
      case PlayerAction.next:
        unawaited(playlist.next());
      case PlayerAction.previous:
        unawaited(playlist.previous());
      case PlayerAction.queue:
        onToggleQueue();
      case PlayerAction.nextChapter:
        unawaited(service.chapterBy(1));
      case PlayerAction.previousChapter:
        unawaited(service.chapterBy(-1));
      case PlayerAction.abLoop:
        unawaited(() async {
          final r = await service.cycleLoop();
          osd.show(switch (r) {
            PlayerService.loopSetA => 'Loop: A set',
            PlayerService.loopSetB => 'Loop: A–B on',
            _ => 'Loop off',
          });
        }());
      case PlayerAction.nextFrame:
        unawaited(service.frameStep());
        osd.show('Next frame');
      case PlayerAction.previousFrame:
        unawaited(service.frameStep(forward: false));
        osd.show('Previous frame');
      case PlayerAction.pip:
        unawaited(ref.read(pipProvider.notifier).toggle());
      case PlayerAction.openFile:
        unawaited(OpenActions.pickFile(ref));
      case PlayerAction.paste:
        unawaited(OpenActions.pasteFromClipboard(ref));
      case PlayerAction.openUrl:
        onOpenUrl?.call();
      case PlayerAction.effects:
        onEffects?.call();
      case PlayerAction.mediaInfo:
        onShowInfo();
      case PlayerAction.screenshot:
        unawaited(ScreenshotActions.take(ref));
      case PlayerAction.settings:
        onOpenSettings();
      case PlayerAction.bookmark:
        unawaited(BookmarkActions.add(ref));
      case PlayerAction.bookmarks:
        unawaited(showBookmarks(context));
      case PlayerAction.jumpToTime:
        unawaited(showJumpToTime(context, ref));
      case PlayerAction.decoder:
        DecoderActions.next(ref);
      case PlayerAction.stats:
        ref.read(statsOverlayProvider.notifier).toggle();
      case PlayerAction.subtitleLines:
        unawaited(showSubtitleLines(context, ref));
      case PlayerAction.quickCommands:
        unawaited(showQuickCommands(context, ref));
      case PlayerAction.exportClip:
        unawaited(_exportClip(context, ref));
      case PlayerAction.markIntro:
        unawaited(ref.read(skipIntroProvider.notifier).mark());
    }
  }

  /// Clip or GIF of the A-B loop (task 8.8).
  static Future<void> _exportClip(BuildContext context, WidgetRef ref) async {
    final gif = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('export-clip'),
        children: [
          SimpleDialogOption(
            key: const Key('export-video'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Video clip'),
          ),
          SimpleDialogOption(
            key: const Key('export-gif'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('GIF'),
          ),
        ],
      ),
    );
    if (gif != null) await ClipExport.export(ref, gif: gif);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _onKey(context, ref, event),
      child: child,
    );
  }
}
