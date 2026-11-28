import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/volume_scale.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Mute button and the volume slider, up to the boost limit (500 % at
/// most), drawn like Harbor's (task 9.1).
class VolumeControl extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (volume, muted) = ref.watch(
      playbackStateProvider.select(
        (s) => (s.value?.volume ?? 100, s.value?.isMuted ?? false),
      ),
    );
    final max = ref.watch(settingsProvider.select((s) => s.volumeBoostMax));
    final silent = muted || volume == 0;

    void warn(String message) =>
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(message)));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ControlButton(
          key: const Key('mute'),
          icon: silent ? Icons.volume_off : Icons.volume_up,
          tooltip: muted
              ? context.l10n.unmuteTooltip
              : context.l10n.muteTooltip,
          onPressed: () => unawaited(VolumeActions.toggleMute(ref)),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: VolumeSlider.trackWidth,
          child: VolumeSlider(
            value: muted ? 0 : volume,
            max: max,
            onChanged: (v) => unawaited(
              VolumeActions.set(ref, v, persist: false, onFirstBoost: warn),
            ),
            onChangeEnd: (v) => unawaited(VolumeActions.set(ref, v)),
          ),
        ),
      ],
    );
  }
}

/// Harbor's volume slider: 0–100 % on the first 64 % of the track, the
/// boost after a tick, filling from orange to red; the value shows in a
/// bubble over the thumb while it is hovered or dragged.
class VolumeSlider extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.max = 500,
    super.key,
  });

  static const trackWidth = 128.0;

  final double value;

  /// The top of the track, 100–500 %.
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double? _drag;
  bool _hover = false;

  double _valueAt(double x, double width) =>
      VolumeScale.valueAt(x / width, widget.max);

  void _scroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.scrollDelta.dy == 0) return;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final step = shift ? 50.0 : VolumeActions.step;
    final v = (widget.value - e.scrollDelta.dy.sign * step).clamp(
      0.0,
      widget.max,
    );
    widget.onChanged(v);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final value = (_drag ?? widget.value).clamp(0.0, widget.max);
    final active = _hover || _drag != null;
    final boost = VolumeScale.boostAmount(value, widget.max);
    return Semantics(
      slider: true,
      label: context.l10n.volume,
      value: '${value.round()}%',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final x = w * VolumeScale.fraction(value, widget.max);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              onPointerSignal: _scroll,
              child: GestureDetector(
                key: const Key('volume-slider'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final v = _valueAt(d.localPosition.dx, w);
                  widget.onChanged(v);
                  widget.onChangeEnd?.call(v);
                },
                onHorizontalDragStart: (d) {
                  setState(() => _drag = _valueAt(d.localPosition.dx, w));
                  widget.onChanged(_drag!);
                },
                onHorizontalDragUpdate: (d) {
                  setState(() => _drag = _valueAt(d.localPosition.dx, w));
                  widget.onChanged(_drag!);
                },
                onHorizontalDragEnd: (_) {
                  final v = _drag;
                  setState(() => _drag = null);
                  if (v != null) widget.onChangeEnd?.call(v);
                },
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: active ? 1 : 0),
                          duration: const Duration(milliseconds: 200),
                          curve: const Cubic(0.22, 0.61, 0.36, 1),
                          builder: (context, t, _) => CustomPaint(
                            painter: VolumeSliderPainter(
                              value: value,
                              max: widget.max,
                              emphasis: t,
                            ),
                          ),
                        ),
                      ),
                      if (active)
                        Positioned(
                          left: x - 24,
                          width: 48,
                          bottom: 36,
                          child: Center(
                            child: _Bubble(
                              text: '${value.round()}%',
                              color: boost > 0
                                  ? KyndrelColors.boost(boost)
                                  : KyndrelColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('volume-label'),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: KyndrelColors.titleBarScrim,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// The track, the boost zone, the fill and the thumb. [emphasis] grows
/// the track (7 → 12 px) and the thumb (14 → 19 px) while hovered.
class VolumeSliderPainter extends CustomPainter {
  new({required this.value, required this.max, this.emphasis = 0});

  final double value;
  final double max;
  final double emphasis;

  @override
  void paint(Canvas canvas, Size size) {
    final h = 7 + 5 * emphasis;
    final y = size.height / 2;
    final r = Radius.circular(h / 2);
    final track = RRect.fromLTRBR(0, y - h / 2, size.width, y + h / 2, r);
    final boosts = max > 100;
    final unity = size.width * VolumeScale.fraction(100, max);
    final x = size.width * VolumeScale.fraction(value, max);
    final boost = VolumeScale.boostAmount(value, max);
    final color = boost > 0
        ? KyndrelColors.boost(boost)
        : KyndrelColors.textPrimary;

    canvas.drawRRect(track, Paint()..color = KyndrelColors.track);
    if (boosts) {
      final zone = Rect.fromLTRB(unity, y - h / 2, size.width, y + h / 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(zone, topRight: r, bottomRight: r),
        Paint()
          ..shader = const LinearGradient(
            colors: [KyndrelColors.boostZoneLow, KyndrelColors.boostZoneHigh],
          ).createShader(zone),
      );
    }
    if (x > 0) {
      final fill = Rect.fromLTRB(0, y - h / 2, x, y + h / 2);
      final paint = Paint();
      if (boost > 0) {
        final split = (unity / x).clamp(0.0, 1.0);
        paint.shader = LinearGradient(
          colors: [
            KyndrelColors.textPrimary,
            KyndrelColors.textPrimary,
            KyndrelColors.boostLow,
            color,
          ],
          stops: [0, split, split, 1],
        ).createShader(fill);
      } else {
        paint.color = KyndrelColors.textPrimary;
      }
      canvas.drawRRect(RRect.fromRectAndRadius(fill, r), paint);
    }
    if (boosts) {
      // 100 %: where the boost begins.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(unity, y), width: 2, height: h),
          const Radius.circular(1),
        ),
        Paint()..color = KyndrelColors.trackBuffered,
      );
    }
    final thumb = 7 + 2.5 * emphasis;
    canvas
      ..drawCircle(
        Offset(x, y + 1),
        thumb + 1,
        Paint()
          ..color = KyndrelColors.titleBarScrim
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawCircle(Offset(x, y), thumb, Paint()..color = color);
  }

  @override
  bool shouldRepaint(VolumeSliderPainter old) =>
      old.value != value || old.max != max || old.emphasis != emphasis;
}
