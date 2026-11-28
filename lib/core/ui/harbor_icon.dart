import 'package:material_ui/material_ui.dart';
import 'package:path_parsing/path_parsing.dart';

/// One path of a [HarborIconData], in the icon's 512 × 512 box, with the
/// group transform some icons have (x' = dx + scale × x).
@immutable
class HarborIconPath {
  const new(this.data, {this.scale = 1, this.dx = 0, this.dy = 0});

  final String data;
  final double scale;
  final double dx;
  final double dy;
}

/// A Harbor player icon (task 9.2): filled paths in a 512 × 512 box.
@immutable
class HarborIconData {
  const new(this.paths);

  final List<HarborIconPath> paths;

  static const box = 512.0;

  static final _parsed = Expando<Path>('harbor icon');

  /// The whole icon as one path in the 512 box, parsed once.
  Path get path => _parsed[this] ??= () {
    final out = Path()..fillType = PathFillType.nonZero;
    for (final p in paths) {
      final proxy = _PathProxy();
      writeSvgPathDataToPath(p.data, proxy);
      final m = Matrix4.identity()
        ..translateByDouble(p.dx, p.dy, 0, 1)
        ..scaleByDouble(p.scale, p.scale, 1, 1);
      out.addPath(proxy.path, Offset.zero, matrix4: m.storage);
    }
    return out;
  }();
}

class _PathProxy extends PathProxy {
  final path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

/// Paints a [HarborIconData] at [size] in [color] (the current icon colour
/// by default), like an [Icon].
class HarborIcon extends StatelessWidget {
  const new(this.icon, {this.size, this.color, super.key});

  final HarborIconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFFFFFFFF);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: s,
        child: CustomPaint(painter: _HarborIconPainter(icon, c)),
      ),
    );
  }
}

class _HarborIconPainter extends CustomPainter {
  new(this.icon, this.color);

  final HarborIconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / HarborIconData.box;
    canvas
      ..save()
      ..scale(k)
      ..drawPath(
        icon.path,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HarborIconPainter old) =>
      old.icon != icon || old.color != color;
}
