import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:material_ui/material_ui.dart';

class FullscreenButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final full = ref.watch(isFullScreenProvider).value ?? false;
    return ControlButton(
      key: const Key('fullscreen'),
      icon: full ? Icons.fullscreen_exit : Icons.fullscreen,
      tooltip: full ? 'Exit full screen (F)' : 'Full screen (F)',
      size: 26,
      onPressed: () => unawaited(FullscreenActions.toggle(ref)),
    );
  }
}
