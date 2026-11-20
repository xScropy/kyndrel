import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A vinyl record with the cover art as its label, turning while the music
/// plays and easing to a stop when it pauses (task 7.6).
class SpinningDisc extends StatefulWidget {
  const new({required this.playing, this.cover, this.still = false, super.key});

  final bool playing;

  /// The song's cover; a plain label without one.
  final String? cover;

  /// Less motion: the disc doesn't turn.
  final bool still;

  /// One turn while playing.
  static const turn = Duration(seconds: 8);

  @override
  State<SpinningDisc> createState() => SpinningDiscState();
}

class SpinningDiscState extends State<SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// Radians turned so far.
  double angle = 0;

  /// Turns per second now (eases towards the target).
  double _speed = 0;

  double get _target =>
      widget.playing && !widget.still ? 1 / SpinningDisc.turn.inSeconds : 0;

  @override
  void initState() {
    super.initState();
    _speed = _target;
    _sync();
  }

  @override
  void didUpdateWidget(SpinningDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if ((_target > 0 || _speed > 0) && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Ease: about half a second to get going or come to rest.
    _speed += (_target - _speed) * math.min(1, dt * 4);
    if (_target == 0 && _speed < 0.002) {
      _speed = 0;
      _ticker.stop();
    }
    setState(() => angle = (angle + _speed * dt * 2 * math.pi) % (2 * math.pi));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Transform.rotate(
          key: const Key('disc-rotation'),
          angle: angle,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _VinylPainter()),
              FractionallySizedBox(
                widthFactor: 0.42,
                heightFactor: 0.42,
                child: ClipOval(child: _Label(cover: widget.cover)),
              ),
            ],
          ),
        ),
        // The light falls the same way however the disc turns.
        const IgnorePointer(child: CustomPaint(painter: _SheenPainter())),
        const FractionallySizedBox(
          widthFactor: 0.035,
          heightFactor: 0.035,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: KyndrelColors.background,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const new({this.cover});

  final String? cover;

  @override
  Widget build(BuildContext context) {
    const plain = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [KyndrelColors.accent, KyndrelColors.accentPressed],
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.4,
          child: FittedBox(
            child: Icon(Icons.music_note, color: KyndrelColors.onAccent),
          ),
        ),
      ),
    );
    final c = cover;
    if (c == null) return plain;
    return Image.file(
      File(c),
      key: const Key('disc-cover'),
      fit: BoxFit.cover,
      cacheWidth: 512,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => plain,
    );
  }
}

/// The record: black vinyl with fine grooves.
class _VinylPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = KyndrelColors.vinyl);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = KyndrelColors.vinylGroove;
    for (var g = r * 0.25; g < r * 0.96; g += r * 0.025) {
      canvas.drawCircle(c, g, groove);
    }
    // The lead-in and the edge.
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = KyndrelColors.vinylEdge,
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => false;
}

/// Light on the grooves: two soft bright wedges.
class _SheenPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0x00FFFFFF),
            KyndrelColors.vinylSheen,
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            KyndrelColors.vinylSheen,
            Color(0x00FFFFFF),
          ],
          stops: [0.05, 0.12, 0.2, 0.55, 0.62, 0.7],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => false;
}
