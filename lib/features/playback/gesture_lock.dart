import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:material_ui/material_ui.dart';

/// Screen lock (task 6.3): while on, touches don't seek, pause or change
/// volume, so a phone in a pocket or a child's hands stays put.
class GestureLock extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;
  void unlock() => state = false;
}

final gestureLockProvider = NotifierProvider<GestureLock, bool>(
  GestureLock.new,
);

/// The lock button in the controls.
class LockButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ControlButton(
    key: const Key('lock'),
    icon: Icons.lock_open,
    tooltip: 'Lock screen',
    onPressed: ref.read(gestureLockProvider.notifier).lock,
  );
}

/// Shown instead of the controls while locked: a tap reveals the unlock
/// button for a few seconds; nothing else gets through.
class LockedOverlay extends ConsumerStatefulWidget {
  const new({super.key});

  static const showFor = Duration(seconds: 3);

  @override
  ConsumerState<LockedOverlay> createState() => _LockedOverlayState();
}

class _LockedOverlayState extends ConsumerState<LockedOverlay> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  void _reveal() {
    setState(() => _visible = true);
    _timer?.cancel();
    _timer = Timer(LockedOverlay.showFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('locked-overlay'),
      behavior: HitTestBehavior.opaque,
      // Opaque and on top: the video's gestures underneath never see the
      // touch, so a tap only has to reveal the unlock button.
      onTap: _reveal,
      child: Align(
        alignment: const Alignment(0, 0.75),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_visible,
            child: Material(
              color: KyndrelColors.panel,
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('unlock'),
                tooltip: 'Unlock',
                iconSize: 28,
                padding: const EdgeInsets.all(14),
                icon: const Icon(Icons.lock, color: KyndrelColors.accent),
                onPressed: ref.read(gestureLockProvider.notifier).unlock,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
