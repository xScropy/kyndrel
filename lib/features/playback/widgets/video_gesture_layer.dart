import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/brightness_service.dart';
import 'package:kyndrel/core/platform/system_volume.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/video_view_settings.dart';
import 'package:kyndrel/core/player/volume_scale.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/playback/fullscreen_actions.dart';
import 'package:kyndrel/features/playback/screenshot_actions.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Mouse and touch gestures on the video (tasks 1.7, 1.10, 6.3).
///
/// Mouse: click play/pause, double-click full screen, wheel volume.
///
/// Touch (each can be turned off in Settings › Gestures):
/// - tap: show/hide the controls
/// - horizontal swipe: seek, applied on release ([seekPreview] shows where)
/// - vertical swipe, left half: brightness; right half: volume, the phone's
///   first, then Kyndrel's boost up to 200 %
/// - double-tap the left/right third: −/+ the skip length, adding up on
///   repeated double-taps; the middle: play/pause
/// - pinch: zoom; long-press: 2× speed while held
/// Swipes starting at the very edges are left to the system (back gesture,
/// notification shade).
class VideoGestureLayer extends ConsumerStatefulWidget {
  const new({this.onSecondaryTap, super.key});

  /// Right-click (context menu), with the global position.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Full drag across the width seeks this far (less for short videos).
  static const fullWidthSeek = Duration(minutes: 3);

  /// A full-height swipe moves brightness or volume over its whole range.
  static const fullHeightFraction = 0.8;

  /// Distance before a drag picks an axis.
  static const slop = 12.0;

  /// Margins left to the system's own edge gestures.
  static const edgeInset = 24.0;
  static const topInset = 40.0;

  /// Double-taps within this of each other add up (+10, +20, …).
  static const streakWindow = Duration(milliseconds: 900);

  /// Speed while long-pressing.
  static const holdRate = 2.0;

  /// Sideways distance for one 0.25× step while holding (task 8.8).
  static const holdSlideStep = 40.0;

  /// Where a swipe-seek would land; the scene preview (6.4) follows it.
  static final seekPreview = ValueNotifier<Duration?>(null);

  @override
  ConsumerState<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

enum _Drag { none, seek, brightness, volume, pinch, ignored }

class _VideoGestureLayerState extends ConsumerState<VideoGestureLayer> {
  PointerDeviceKind _lastKind = PointerDeviceKind.mouse;

  /// Where the finger went down: the scale recognizer only reports moves
  /// after its own slop, so distances are measured from here.
  Offset? _pointerDownAt;

  _Drag _drag = _Drag.none;
  Offset _dragOrigin = Offset.zero;
  Offset _dragDelta = Offset.zero;
  Duration? _seekStart;
  Duration? _seekTarget;
  double? _levelStart;
  double _zoomStart = 1;

  Offset? _doubleTapAt;
  int _streakSign = 0;
  Duration _streak = Duration.zero;
  DateTime? _lastDoubleTap;

  double? _rateBeforeHold;

  bool get _isTouch =>
      _lastKind == PointerDeviceKind.touch ||
      _lastKind == PointerDeviceKind.stylus;

  AppSettings? get _settings {
    try {
      return ref.read(settingsProvider);
    } on Object {
      return null; // Tests without settings: all gestures on.
    }
  }

  Size get _size => context.size ?? const Size(1, 1);

  void _onTap() {
    if (_isTouch) {
      ref.read(controlsVisibilityProvider.notifier).toggle();
    } else {
      unawaited(ref.read(playerServiceProvider).playOrPause());
      ref.read(controlsVisibilityProvider.notifier).show();
    }
  }

  // ------------------------------------------------------------ double-tap

  void _onDoubleTap() {
    if (!_isTouch) {
      unawaited(FullscreenActions.toggle(ref));
      return;
    }
    final at = _doubleTapAt ?? Offset(_size.width / 2, 0);
    final third = _size.width / 3;
    final service = ref.read(playerServiceProvider);
    if ((_settings?.gestureDoubleTap ?? true) && at.dx < third) {
      _seekStreak(-1);
    } else if ((_settings?.gestureDoubleTap ?? true) &&
        at.dx > _size.width - third) {
      _seekStreak(1);
    } else {
      unawaited(service.playOrPause());
    }
  }

  void _seekStreak(int sign) {
    final skip = Duration(seconds: _settings?.skipSeconds ?? 10);
    final now = DateTime.now();
    final last = _lastDoubleTap;
    final continues =
        last != null &&
        now.difference(last) < VideoGestureLayer.streakWindow &&
        sign == _streakSign;
    _streak = continues ? _streak + skip : skip;
    _streakSign = sign;
    _lastDoubleTap = now;
    unawaited(ref.read(playerServiceProvider).seekBy(skip * sign));
    ref
        .read(osdProvider.notifier)
        .show('${sign < 0 ? '−' : '+'}${_streak.inSeconds} s');
  }

  // ------------------------------------------------------------ long-press

  void _onLongPressStart(LongPressStartDetails _) {
    if (!_isTouch || !(_settings?.gestureLongPress ?? true)) return;
    final service = ref.read(playerServiceProvider);
    if (!service.state.isPlaying) return;
    _rateBeforeHold = service.state.rate;
    unawaited(service.setRate(VideoGestureLayer.holdRate));
    ref.read(osdProvider.notifier).show('2× ▶▶');
  }

  /// While holding: sliding sideways changes the speed in 0.25 steps,
  /// 1× to 4× (mpvKt).
  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (_rateBeforeHold == null) return;
    final steps = (d.offsetFromOrigin.dx / VideoGestureLayer.holdSlideStep)
        .round();
    final rate = (VideoGestureLayer.holdRate + steps * 0.25).clamp(1.0, 4.0);
    final service = ref.read(playerServiceProvider);
    if (rate == service.state.rate) return;
    unawaited(service.setRate(rate));
    ref.read(osdProvider.notifier).show('${_rateLabel(rate)}× ▶▶');
  }

  static String _rateLabel(double r) =>
      r == r.roundToDouble() ? '${r.round()}' : '$r';

  void _onLongPressEnd([Object? _]) {
    final rate = _rateBeforeHold;
    _rateBeforeHold = null;
    if (rate != null) unawaited(ref.read(playerServiceProvider).setRate(rate));
  }

  // ------------------------------------------------------------ drags

  void _onScaleStart(ScaleStartDetails d) {
    _dragOrigin = _pointerDownAt ?? d.localFocalPoint;
    _dragDelta = d.localFocalPoint - _dragOrigin;
    if (d.pointerCount >= 2) {
      _drag = (_settings?.gesturePinch ?? true) ? _Drag.pinch : _Drag.ignored;
      _zoomStart = ref.read(videoViewProvider).zoom;
      return;
    }
    final x = _dragOrigin.dx;
    final atEdge =
        x < VideoGestureLayer.edgeInset ||
        x > _size.width - VideoGestureLayer.edgeInset ||
        _dragOrigin.dy < VideoGestureLayer.topInset;
    _drag = atEdge ? _Drag.ignored : _Drag.none;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2 && _drag != _Drag.pinch) {
      // A second finger joined: switch to zooming.
      _cancelDrag();
      _drag = (_settings?.gesturePinch ?? true) ? _Drag.pinch : _Drag.ignored;
      _zoomStart = ref.read(videoViewProvider).zoom;
      return;
    }
    switch (_drag) {
      case _Drag.ignored:
        return;
      case _Drag.pinch:
        ref.read(videoViewProvider.notifier).setZoom(_zoomStart * d.scale);
        ref
            .read(osdProvider.notifier)
            .show('Zoom ${(ref.read(videoViewProvider).zoom * 100).round()}%');
        return;
      case _Drag.none:
        _dragDelta = d.localFocalPoint - _dragOrigin;
        if (_dragDelta.distance < VideoGestureLayer.slop) return;
        _pickAxis();
      case _Drag.seek:
      case _Drag.brightness:
      case _Drag.volume:
        _dragDelta = d.localFocalPoint - _dragOrigin;
    }
    _applyDrag();
  }

  void _pickAxis() {
    final s = _settings;
    if (_dragDelta.dx.abs() > _dragDelta.dy.abs()) {
      final state = ref.read(playerServiceProvider).state;
      if (!(s?.gestureSeek ?? true) || state.duration <= Duration.zero) {
        _drag = _Drag.ignored;
        return;
      }
      _drag = _Drag.seek;
      _seekStart = state.position;
      return;
    }
    final left = _dragOrigin.dx < _size.width / 2;
    if (left) {
      final brightness = ref.read(brightnessServiceProvider);
      if (brightness == null || !(s?.gestureBrightness ?? true)) {
        _drag = _Drag.ignored;
        return;
      }
      _drag = _Drag.brightness;
      _levelStart = null;
      unawaited(brightness.current().then((v) => _levelStart ??= v));
    } else {
      if (!(s?.gestureVolume ?? true)) {
        _drag = _Drag.ignored;
        return;
      }
      _drag = _Drag.volume;
      _levelStart = null;
      unawaited(_combinedVolume().then((v) => _levelStart ??= v));
    }
  }

  Future<double> _combinedVolume() async {
    final player = ref.read(playerServiceProvider).state.volume;
    final system = ref.read(systemVolumeProvider);
    if (system == null) return player.clamp(0, CombinedVolume.max).toDouble();
    return CombinedVolume.of(system: await system.current(), player: player);
  }

  /// Upward swipe as a share of the range (−1…1).
  double get _verticalFraction =>
      -_dragDelta.dy / (_size.height * VideoGestureLayer.fullHeightFraction);

  void _applyDrag() {
    switch (_drag) {
      case _Drag.seek:
        _applySeek();
      case _Drag.brightness:
        final start = _levelStart;
        if (start == null) return; // Reading the current value.
        final v = (start + _verticalFraction).clamp(0.0, 1.0);
        unawaited(ref.read(brightnessServiceProvider)?.set(v));
        ref
            .read(levelOsdProvider.notifier)
            .show(OsdLevel(LevelKind.brightness, v));
      case _Drag.volume:
        final start = _levelStart;
        if (start == null) return;
        // On the same scale as the slider: 100 % at 64 % of the way.
        final max = ref.read(settingsProvider).volumeBoostMax;
        final v = VolumeScale.valueAt(
          VolumeScale.fraction(start, max) + _verticalFraction,
          max,
        );
        unawaited(_setCombinedVolume(v));
        ref
            .read(levelOsdProvider.notifier)
            .show(OsdLevel(LevelKind.volume, v, max: max));
      case _Drag.none:
      case _Drag.pinch:
      case _Drag.ignored:
        break;
    }
  }

  Future<void> _setCombinedVolume(double combined) async {
    final system = ref.read(systemVolumeProvider);
    if (system == null) {
      await VolumeActions.set(ref, combined, persist: false);
      return;
    }
    final split = CombinedVolume.split(combined);
    await system.set(split.system);
    await VolumeActions.set(ref, split.player, persist: false);
  }

  void _applySeek() {
    final start = _seekStart;
    if (start == null) return;
    final duration = ref.read(playerServiceProvider).state.duration;
    // A whole short clip fits in one swipe.
    final full = duration < VideoGestureLayer.fullWidthSeek
        ? duration
        : VideoGestureLayer.fullWidthSeek;
    final offset = full * (_dragDelta.dx / _size.width);
    var target = start + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    _seekTarget = target;
    VideoGestureLayer.seekPreview.value = target;
    final sign = offset.isNegative ? '-' : '+';
    ref
        .read(osdProvider.notifier)
        .show(
          '$sign${formatDuration(offset.abs())} (${formatDuration(target)})',
        );
  }

  void _onScaleEnd(ScaleEndDetails _) {
    switch (_drag) {
      case _Drag.seek:
        final target = _seekTarget;
        if (target != null) {
          unawaited(ref.read(playerServiceProvider).seek(target));
        }
      case _Drag.volume:
        // Remember Kyndrel's part for next time, like the slider does.
        unawaited(
          VolumeActions.set(ref, ref.read(playerServiceProvider).state.volume),
        );
      case _Drag.brightness:
      case _Drag.none:
      case _Drag.pinch:
      case _Drag.ignored:
        break;
    }
    _cancelDrag();
  }

  void _cancelDrag() {
    _drag = _Drag.none;
    _seekStart = null;
    _seekTarget = null;
    _levelStart = null;
    VideoGestureLayer.seekPreview.value = null;
  }

  // ------------------------------------------------------------ mouse

  /// Middle, back and forward mouse buttons (task 8.8), as set in
  /// Settings › Shortcuts.
  void _mouseButton(int buttons) {
    // Tests without settings: the defaults.
    final s = _settings ?? const AppSettings();
    final service = ref.read(playerServiceProvider);
    final osd = ref.read(osdProvider.notifier);
    if (buttons & kMiddleMouseButton != 0) {
      switch (s.mouseMiddle) {
        case 'playPause':
          unawaited(service.playOrPause());
        case 'mute':
          unawaited(VolumeActions.toggleMute(ref));
        case 'fullscreen':
          unawaited(FullscreenActions.toggle(ref));
        case 'screenshot':
          unawaited(ScreenshotActions.take(ref));
      }
      return;
    }
    final back = buttons & kBackMouseButton != 0;
    final forward = buttons & kForwardMouseButton != 0;
    if (!back && !forward) return;
    if (s.mouseSide == 'seek') {
      final skip = Duration(seconds: s.skipSeconds);
      unawaited(service.seekBy(back ? -skip : skip));
      osd.show('${back ? '−' : '+'}${skip.inSeconds} s');
    } else if (s.mouseSide == 'playlist') {
      final playlist = ref.read(playlistProvider.notifier);
      unawaited(back ? playlist.previous() : playlist.next());
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _lastKind = e.kind;
        _pointerDownAt = e.localPosition;
        if (e.kind == PointerDeviceKind.mouse) _mouseButton(e.buttons);
      },
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
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: _onDoubleTap,
          onSecondaryTapUp: widget.onSecondaryTap == null
              ? null
              : (d) => widget.onSecondaryTap!(d.globalPosition),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
            },
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMove,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: _onLongPressEnd,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
          ),
        ),
      ),
    );
  }
}
