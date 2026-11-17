import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/features/playback/volume_actions.dart';
import 'package:material_ui/material_ui.dart';

/// Mute button, 0–400 % slider and orange percentage (task 1.6).
class VolumeControl extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (volume, muted) = ref.watch(
      playbackStateProvider.select(
        (s) => (s.value?.volume ?? 100, s.value?.isMuted ?? false),
      ),
    );
    final icon = muted || volume == 0
        ? Icons.volume_off
        : volume < 50
        ? Icons.volume_down
        : Icons.volume_up;

    void warn(String message) =>
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(message)));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ControlButton(
          key: const Key('mute'),
          icon: icon,
          tooltip: muted ? 'Unmute (M)' : 'Mute (M)',
          onPressed: () => unawaited(VolumeActions.toggleMute(ref)),
        ),
        SizedBox(
          width: 130,
          child: VolumeSlider(
            value: muted ? 0 : volume,
            onChanged: (v) => unawaited(
              VolumeActions.set(ref, v, persist: false, onFirstBoost: warn),
            ),
            onChangeEnd: (v) => unawaited(VolumeActions.set(ref, v)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${(muted ? 0 : volume).round()}%',
            key: const Key('volume-label'),
            style: const TextStyle(
              color: KyndrelColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal 0–400 slider with a marker at 100 % and the boosted part in
/// the accent colour.
class VolumeSlider extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.max = PlayerService.maxVolume,
    super.key,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Values this close to 100 snap to exactly 100 while dragging.
  static const snap = 4.0;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double? _drag;
  bool _hover = false;

  double _valueAt(double x, double width) {
    final v = ((x / width).clamp(0.0, 1.0) * widget.max).roundToDouble();
    return (v - 100).abs() <= VolumeSlider.snap ? 100 : v;
  }

  @override
  Widget build(BuildContext context) {
    final value = _drag ?? widget.value;
    return Semantics(
      slider: true,
      label: 'Volume',
      value: '${value.round()}%',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  final v =
                      (widget.value -
                              e.scrollDelta.dy.sign * VolumeActions.step)
                          .clamp(0.0, widget.max);
                  widget.onChanged(v);
                  widget.onChangeEnd?.call(v);
                }
              },
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
                  height: 32,
                  child: CustomPaint(
                    painter: VolumeSliderPainter(
                      value: value,
                      max: widget.max,
                      emphasised: _hover || _drag != null,
                    ),
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

class VolumeSliderPainter extends CustomPainter {
  new({required this.value, required this.max, required this.emphasised});

  final double value;
  final double max;
  final bool emphasised;

  @override
  void paint(Canvas canvas, Size size) {
    final h = emphasised ? 5.0 : 4.0;
    final y = size.height / 2;
    final r = Radius.circular(h / 2);
    double x(double v) => size.width * (v / max).clamp(0.0, 1.0);
    RRect seg(double from, double to) =>
        RRect.fromLTRBR(from, y - h / 2, to, y + h / 2, r);

    final unity = x(100);
    canvas
      // Unfilled: normal range, then the boost zone tinted orange.
      ..drawRRect(seg(0, unity), Paint()..color = KyndrelColors.track)
      ..drawRRect(
        seg(unity, size.width),
        Paint()..color = KyndrelColors.accent.withValues(alpha: 0.22),
      )
      // Filled: white up to 100 %, accent beyond.
      ..drawRRect(
        seg(0, x(value < 100 ? value : 100)),
        Paint()..color = KyndrelColors.textPrimary,
      );
    if (value > 100) {
      canvas.drawRRect(
        seg(unity, x(value)),
        Paint()..color = KyndrelColors.accent,
      );
    }
    // 100 % marker.
    canvas
      ..drawRect(
        Rect.fromCenter(center: Offset(unity, y), width: 2, height: 12),
        Paint()..color = KyndrelColors.textSecondary,
      )
      ..drawCircle(
        Offset(x(value), y),
        emphasised ? 7 : 6,
        Paint()
          ..color = value > 100
              ? KyndrelColors.accent
              : KyndrelColors.textPrimary,
      );
  }

  @override
  bool shouldRepaint(VolumeSliderPainter old) =>
      old.value != value || old.max != max || old.emphasised != emphasised;
}
