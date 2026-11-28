import 'package:flutter/foundation.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// How the seek bar looks (task 9.3, Harbor's options), from settings.
@immutable
class SeekBarLook {
  const new({
    this.style = SeekBarStyle.flat,
    this.height = 6,
    this.color = KyndrelColors.seekAmber,
    this.dotShape = SeekDotShape.circle,
    this.dotSize = 16,
    this.dotOnHover = true,
  });

  factory fromSettings(AppSettings s) => SeekBarLook(
    style: s.seekBarStyle,
    height: s.seekBarHeight,
    color: Color(s.seekBarColor),
    dotShape: s.seekDotShape,
    dotSize: s.seekDotSize,
    dotOnHover: s.seekDotOnHover,
  );

  final SeekBarStyle style;

  /// Thickness at rest; +2 px on hover, +4 px while dragging.
  final double height;
  final Color color;
  final SeekDotShape dotShape;

  /// Thumb size at rest; +3 px on hover, +6 px while dragging.
  final double dotSize;

  /// The thumb shows only while the bar is hovered or dragged.
  final bool dotOnHover;

  @override
  bool operator ==(Object other) =>
      other is SeekBarLook &&
      other.style == style &&
      other.height == height &&
      other.color == color &&
      other.dotShape == dotShape &&
      other.dotSize == dotSize &&
      other.dotOnHover == dotOnHover;

  @override
  int get hashCode =>
      Object.hash(style, height, color, dotShape, dotSize, dotOnHover);
}

class SeekBarPainter extends CustomPainter {
  new({
    required this.progress,
    required this.buffered,
    required this.hovering,
    this.scrubbing = false,
    this.look = const SeekBarLook(),
    this.marks = const [],
    this.bookmarks = const [],
    this.heat = const [],
    this.loopA,
    this.loopB,
  });

  /// "Most replayed": 0–1 heights along the bar (task 8.10), drawn while
  /// hovering.
  final List<double> heat;

  /// Bookmarks as 0–1 fractions (task 8.8): small ticks above.
  final List<double> bookmarks;

  final double progress;
  final double buffered;
  final bool hovering;

  /// A drag is under way: the bar and the thumb grow a step more.
  final bool scrubbing;
  final SeekBarLook look;

  /// Chapter starts as 0–1 fractions (task 3.6).
  final List<double> marks;

  /// A-B loop points as fractions (task 3.9).
  final double? loopA;
  final double? loopB;

  @override
  void paint(Canvas canvas, Size size) {
    final track = look.height + (scrubbing ? 4 : (hovering ? 2 : 0));
    final y = size.height / 2;
    final r = Radius.circular(track / 2);
    RRect bar(double to) =>
        RRect.fromLTRBR(0, y - track / 2, to, y + track / 2, r);
    final color = look.color;

    // Most replayed: a soft curve above the bar while hovering.
    if (hovering && heat.length > 1) {
      final top = y - track / 2 - 2;
      const tall = 14.0;
      final path = Path()..moveTo(0, top);
      for (var i = 0; i < heat.length; i++) {
        final x = size.width * (i + 0.5) / heat.length;
        path.lineTo(x, top - tall * heat[i]);
      }
      path
        ..lineTo(size.width, top)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35));
    }
    canvas
      ..drawRRect(bar(size.width), Paint()..color = KyndrelColors.seekTrack)
      ..drawRRect(
        bar(size.width * buffered),
        Paint()..color = KyndrelColors.seekBuffered,
      );
    _paintFill(canvas, bar(size.width * progress));
    // Chapter marks: small gaps in the bar.
    final gap = Paint()..color = KyndrelColors.background;
    for (final m in marks) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * m, y),
          width: 2,
          height: track + 1,
        ),
        gap,
      );
    }
    // Bookmarks: ticks over the bar.
    final tick = Paint()..color = color;
    for (final b in bookmarks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * b, y - track / 2 - 4),
            width: 3,
            height: 7,
          ),
          const Radius.circular(1.5),
        ),
        tick,
      );
    }
    // A-B loop range.
    final a = loopA;
    if (a != null) {
      final loopPaint = Paint()..color = KyndrelColors.textPrimary;
      final b = loopB;
      if (b != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            size.width * a,
            y - track,
            size.width * b,
            y - track + 2,
          ),
          loopPaint,
        );
      }
      for (final f in [a, ?b]) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width * f, y),
            width: 2,
            height: 14,
          ),
          loopPaint,
        );
      }
    }
    _paintDot(canvas, Offset(size.width * progress, y));
  }

  void _paintFill(Canvas canvas, RRect fill) {
    if (fill.width <= 0) return;
    final rect = fill.outerRect;
    canvas
      ..save()
      ..clipRRect(fill);
    switch (look.style) {
      case SeekBarStyle.rainbow:
        // Six bands, top to bottom.
        final band = rect.height / KyndrelColors.rainbow.length;
        for (var i = 0; i < KyndrelColors.rainbow.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top + band * i, rect.width, band),
            Paint()..color = KyndrelColors.rainbow[i],
          );
        }
      case SeekBarStyle.flat:
      case SeekBarStyle.glass:
      case SeekBarStyle.pinstripe:
        canvas.drawRect(rect, Paint()..color = look.color);
    }
    if (look.style == SeekBarStyle.glass) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              KyndrelColors.glassSheenTop,
              KyndrelColors.glassSheenMid,
              KyndrelColors.glassSheenBottom,
            ],
          ).createShader(rect),
      );
    }
    if (look.style == SeekBarStyle.pinstripe) {
      // A barber pole: 45° light stripes every 8 px.
      final stripe = Paint()
        ..color = KyndrelColors.stripe
        ..strokeWidth = 3;
      for (var x = rect.left - rect.height; x < rect.right; x += 8) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          stripe,
        );
      }
    }
    canvas.restore();
  }

  void _paintDot(Canvas canvas, Offset at) {
    if (look.dotShape == SeekDotShape.hidden) return;
    if (look.dotOnHover && !hovering && !scrubbing) return;
    final size = look.dotSize + (scrubbing ? 6 : (hovering ? 3 : 0));
    final color = look.style == SeekBarStyle.rainbow
        ? KyndrelColors.textPrimary
        : look.color;
    RRect shape(double s) => RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: s, height: s),
      Radius.circular(look.dotShape == SeekDotShape.square ? s * 0.2 : s / 2),
    );
    canvas
      // A soft drop seats it on the track; a tight dark halo keeps it
      // readable over a bright frame (Harbor's thumb).
      ..drawRRect(
        shape(size + 2).shift(const Offset(0, 2)),
        Paint()
          ..color = KyndrelColors.dotShadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawRRect(shape(size + 4), Paint()..color = KyndrelColors.dotHalo)
      ..drawRRect(shape(size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(SeekBarPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.hovering != hovering ||
      old.scrubbing != scrubbing ||
      old.look != look ||
      !listEquals(old.marks, marks) ||
      !listEquals(old.bookmarks, bookmarks) ||
      !listEquals(old.heat, heat) ||
      old.loopA != loopA ||
      old.loopB != loopB;
}
