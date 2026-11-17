import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/features/library/playlist_panel.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';
import 'package:kyndrel/features/playback/screenshot_actions.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:kyndrel/features/speed_sleep/speed_sleep_button.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Keyboard shortcuts (task 1.9). A rebinding screen comes with the settings
/// page (task 5.1); until then the bindings are fixed and listed in
/// [PlayerShortcuts.help].
class PlayerShortcuts extends ConsumerWidget {
  const new({
    required this.child,
    required this.onOpenSettings,
    required this.onShowInfo,
    required this.onToggleQueue,
    super.key,
  });

  final Widget child;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowInfo;
  final VoidCallback onToggleQueue;

  static const help = <(String, String)>[
    ('Space', 'Play / pause'),
    ('← / →', 'Seek back / forward by the skip length'),
    ('↑ / ↓', 'Volume up / down 5%'),
    ('M', 'Mute'),
    ('F', 'Full screen'),
    ('Esc', 'Close panel / leave full screen'),
    ('[ / ]', 'Slower / faster'),
    ('S', 'Subtitles & audio panel'),
    ('N / P', 'Next / previous in the queue'),
    ('PgDn / PgUp', 'Next / previous chapter'),
    ('L', 'A-B loop: set A, set B, clear'),
    ('. / ,', 'Next / previous frame'),
    ('Q', 'Queue'),
    ('Ctrl+O', 'Open file'),
    ('Ctrl+V', 'Open a pasted path or URL'),
    ('Ctrl+I', 'Media info'),
    ('Ctrl+S', 'Screenshot'),
    ('Ctrl+,', 'Settings'),
  ];

  /// True while a text field has focus, so typing isn't hijacked.
  static bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(WidgetRef ref, KeyEvent event) {
    if (event is KeyUpEvent || _typing()) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    final command = keys.isControlPressed || keys.isMetaPressed;
    final service = ref.read(playerServiceProvider);
    final osd = ref.read(osdProvider.notifier);
    ref.read(controlsVisibilityProvider.notifier).show();

    if (command) {
      if (repeat) return KeyEventResult.handled;
      switch (key) {
        case LogicalKeyboardKey.keyO:
          unawaited(OpenActions.pickFile(ref));
        case LogicalKeyboardKey.keyV:
          unawaited(OpenActions.pasteFromClipboard(ref));
        case LogicalKeyboardKey.keyI:
          onShowInfo();
        case LogicalKeyboardKey.keyS:
          unawaited(ScreenshotActions.take(ref));
        case LogicalKeyboardKey.comma:
          onOpenSettings();
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    final skip = Duration(seconds: ref.read(settingsProvider).skipSeconds);
    switch (key) {
      case LogicalKeyboardKey.space:
        if (!repeat) unawaited(service.playOrPause());
      case LogicalKeyboardKey.arrowLeft:
        unawaited(service.seekBy(-skip));
        osd.show('−${skip.inSeconds} s');
      case LogicalKeyboardKey.arrowRight:
        unawaited(service.seekBy(skip));
        osd.show('+${skip.inSeconds} s');
      case LogicalKeyboardKey.arrowUp:
        unawaited(VolumeActions.changeBy(ref, VolumeActions.step));
      case LogicalKeyboardKey.arrowDown:
        unawaited(VolumeActions.changeBy(ref, -VolumeActions.step));
      case LogicalKeyboardKey.keyM:
        if (!repeat) unawaited(VolumeActions.toggleMute(ref));
      case LogicalKeyboardKey.keyF:
        if (!repeat) unawaited(FullscreenActions.toggle(ref));
      case LogicalKeyboardKey.escape:
        if (ref.read(subtitlePanelProvider) != null) {
          ref.read(subtitlePanelProvider.notifier).close();
        } else if (ref.read(playlistPanelProvider)) {
          ref.read(playlistPanelProvider.notifier).close();
        } else {
          unawaited(FullscreenActions.exit(ref));
        }
      case LogicalKeyboardKey.bracketLeft:
        unawaited(SpeedActions.stepDown(ref));
      case LogicalKeyboardKey.bracketRight:
        unawaited(SpeedActions.stepUp(ref));
      case LogicalKeyboardKey.keyS:
        if (!repeat) ref.read(subtitlePanelProvider.notifier).toggle();
      case LogicalKeyboardKey.keyL:
        if (!repeat) {
          unawaited(() async {
            final r = await service.cycleLoop();
            osd.show(switch (r) {
              PlayerService.loopSetA => 'Loop: A set',
              PlayerService.loopSetB => 'Loop: A–B on',
              _ => 'Loop off',
            });
          }());
        }
      case LogicalKeyboardKey.period:
        unawaited(service.frameStep());
        osd.show('Next frame');
      case LogicalKeyboardKey.comma:
        unawaited(service.frameStep(forward: false));
        osd.show('Previous frame');
      case LogicalKeyboardKey.pageDown:
        unawaited(service.chapterBy(1));
      case LogicalKeyboardKey.pageUp:
        unawaited(service.chapterBy(-1));
      case LogicalKeyboardKey.keyN:
        if (!repeat) unawaited(ref.read(playlistProvider.notifier).next());
      case LogicalKeyboardKey.keyP:
        if (!repeat) unawaited(ref.read(playlistProvider.notifier).previous());
      case LogicalKeyboardKey.keyQ:
        if (!repeat) onToggleQueue();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _onKey(ref, event),
      child: child,
    );
  }
}
