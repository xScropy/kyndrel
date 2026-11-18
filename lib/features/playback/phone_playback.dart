import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// How the phone sits while a video plays (task 6.5).
enum PhoneOrientation { auto, landscape, portrait }

/// Phone playback mode: immersive full screen while a video is open, and
/// the screen turned to the video's shape (landscape for wide videos)
/// unless the rotate button chose otherwise. Leaving the video restores
/// the system bars and free rotation.
class PhonePlayback extends Notifier<PhoneOrientation> {
  bool _active = false;

  /// Wide (true), tall (false) or not known yet: re-apply only on changes,
  /// not on every position tick.
  bool? _wide;

  @override
  PhoneOrientation build() {
    // A direct subscription (Riverpod pauses ref.listen on a provider
    // that is only read once).
    final sub = ref.watch(playerServiceProvider).states.listen((s) {
      final playing = s.source != null && s.isLoaded;
      final w = s.videoWidth ?? 0;
      final h = s.videoHeight ?? 0;
      final wide = w > 0 && h > 0 ? w >= h : null;
      if (playing == _active && wide == _wide) return;
      _active = playing;
      _wide = wide;
      unawaited(_apply());
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return PhoneOrientation.auto;
  }

  /// The rotate button: turn to the other orientation and stay there.
  void rotate(Orientation current) {
    state = current == Orientation.landscape
        ? PhoneOrientation.portrait
        : PhoneOrientation.landscape;
    unawaited(_apply());
  }

  Future<void> _apply() async {
    final window = ref.read(windowServiceProvider);
    if (!_active) {
      state = PhoneOrientation.auto;
      await window.setFullScreen(fullScreen: false);
      await SystemChrome.setPreferredOrientations(const []);
      return;
    }
    await window.setFullScreen(fullScreen: true);
    final wide = _wide;
    final want = switch (state) {
      PhoneOrientation.landscape => _landscape,
      PhoneOrientation.portrait => _portrait,
      PhoneOrientation.auto when wide != null => wide ? _landscape : _portrait,
      PhoneOrientation.auto => const <DeviceOrientation>[],
    };
    await SystemChrome.setPreferredOrientations(want);
  }

  static const List<DeviceOrientation> _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const List<DeviceOrientation> _portrait = [
    DeviceOrientation.portraitUp,
  ];
}

final phonePlaybackProvider = NotifierProvider<PhonePlayback, PhoneOrientation>(
  PhonePlayback.new,
);

class RotateButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ControlButton(
    key: const Key('rotate'),
    icon: Icons.screen_rotation,
    tooltip: context.l10n.rotate,
    onPressed: () => ref
        .read(phonePlaybackProvider.notifier)
        .rotate(MediaQuery.orientationOf(context)),
  );
}
