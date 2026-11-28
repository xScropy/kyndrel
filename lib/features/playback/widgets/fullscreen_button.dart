import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/harbor_icons.g.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class FullscreenButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final full = ref.watch(isFullScreenProvider).value ?? false;
    return ControlButton(
      key: const Key('fullscreen'),
      icon: full ? Icons.fullscreen_exit : Icons.fullscreen,
      harbor: full
          ? HarborIcons.fullscreenWindowed
          : HarborIcons.fullscreenFullscreen,
      tooltip: full
          ? context.l10n.exitFullscreenTooltip
          : context.l10n.fullscreenTooltip,
      size: 21,
      onPressed: () => unawaited(FullscreenActions.toggle(ref)),
    );
  }
}
