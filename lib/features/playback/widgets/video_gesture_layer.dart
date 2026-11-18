import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Mouse and touch gestures on the video (tasks 1.7, 1.10):
/// - mouse click: play/pause; double-click: full screen
/// - scroll wheel: volume
/// - touch tap: show/hide controls; touch double-tap: full screen
/// - touch horizontal drag: seek (preview in the OSD, applied on release)
class VideoGestureLayer extends ConsumerStatefulWidget {
  const new({this.onSecondaryTap, super.key});

  /// Right-click (context menu), with the global position.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Full drag across the width seeks this far.
  static const fullWidthSeek = Duration(minutes: 3);

  @override
  ConsumerState<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends ConsumerState<VideoGestureLayer> {
  PointerDeviceKind _lastKind = PointerDeviceKind.mouse;
  Duration? _dragStart;
  Duration? _dragTarget;
  double _dragDx = 0;

  bool get _isTouch =>
      _lastKind == PointerDeviceKind.touch ||
      _lastKind == PointerDeviceKind.stylus;

  void _onTap() {
    if (_isTouch) {
      ref.read(controlsVisibilityProvider.notifier).toggle();
    } else {
      unawaited(ref.read(playerServiceProvider).playOrPause());
      ref.read(controlsVisibilityProvider.notifier).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _lastKind = e.kind,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
          unawaited(
            VolumeActions.changeBy(
              ref,
              -e.scrollDelta.dy.sign * VolumeActions.step,
            ),
          );
        }
      },
      child: Semantics(
        label: context.l10n.videoSurface,
        hint: context.l10n.videoSurfaceHint,
        child: GestureDetector(
          key: const Key('video-gestures'),
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTap: () => unawaited(FullscreenActions.toggle(ref)),
          onSecondaryTapUp: widget.onSecondaryTap == null
              ? null
              : (d) => widget.onSecondaryTap!(d.globalPosition),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
            },
            onHorizontalDragStart: (_) {
              final state = ref.read(playerServiceProvider).state;
              if (state.duration <= Duration.zero) return;
              _dragStart = state.position;
              _dragDx = 0;
            },
            onHorizontalDragUpdate: (d) {
              final start = _dragStart;
              if (start == null) return;
              _dragDx += d.delta.dx;
              final width = context.size?.width ?? 1;
              final duration = ref.read(playerServiceProvider).state.duration;
              final offset =
                  VideoGestureLayer.fullWidthSeek * (_dragDx / width);
              var target = start + offset;
              if (target < Duration.zero) target = Duration.zero;
              if (target > duration) target = duration;
              _dragTarget = target;
              final sign = offset.isNegative ? '-' : '+';
              ref
                  .read(osdProvider.notifier)
                  .show(
                    '$sign${formatDuration(offset.abs())} '
                    '(${formatDuration(target)})',
                  );
            },
            onHorizontalDragEnd: (_) {
              final target = _dragTarget;
              _dragStart = null;
              _dragTarget = null;
              if (target != null) {
                unawaited(ref.read(playerServiceProvider).seek(target));
              }
            },
          ),
        ),
      ),
    );
  }
}
