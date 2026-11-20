import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:material_ui/material_ui.dart';

/// Orange waves that rise and fall with the music (task 7.6): three
/// layered sine waves whose height follows the loudness.
class MusicWaves extends StatefulWidget {
  const new({
    required this.levels,
    required this.playing,
    this.gentle = false,
    super.key,
  });

  /// The loudness, several times a second.
  final Stream<AudioLevel> levels;
  final bool playing;

  /// Less motion: slower, lower waves.
  final bool gentle;

  @override
  State<MusicWaves> createState() => MusicWavesState();
}

class MusicWavesState extends State<MusicWaves>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<AudioLevel>? _sub;
  Duration _last = Duration.zero;
  double _target = 0;

  /// The height the waves show now, 0–1 (smoothed).
  double level = 0;

  /// Moves the waves along.
  double phase = 0;

  @override
  void initState() {
    super.initState();
    _listen();
    _ticker.start();
  }

  @override
  void didUpdateWidget(MusicWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levels != widget.levels) _listen();
  }

  void _listen() {
    unawaited(_sub?.cancel());
    _sub = widget.levels.listen((l) {
      // RMS for the body, a little of the peak for the punch.
      _target = (l.rms * 0.8 + l.peak * 0.2).clamp(0.0, 1.0);
    });
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final target = widget.playing ? _target : 0.0;
    // Up quickly, down slowly, like a meter.
    final rate = target > level ? 12.0 : 3.0;
    final speed = widget.gentle ? 0.6 : 1.6;
    setState(() {
      level += (target - level) * math.min(1, dt * rate);
      if (widget.playing) phase += dt * speed * (0.6 + level);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('music-waves'),
    painter: WavesPainter(
      level: widget.gentle ? level * 0.5 : level,
      phase: phase,
    ),
    size: Size.infinite,
  );
}

class WavesPainter extends CustomPainter {
  const new({required this.level, required this.phase});

  final double level;
  final double phase;

  /// (height share, wavelengths across, speed, colour).
  static const List<(double, double, double, Color)> _waves = [
    (1.0, 1.6, 1.0, KyndrelColors.accent),
    (0.7, 2.3, -1.4, KyndrelColors.waveMiddle),
    (0.45, 3.1, 2.1, KyndrelColors.waveBack),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    // Never quite flat while there is sound.
    final height = mid * (0.06 + 0.94 * level);
    for (final (share, lengths, speed, color) in _waves.reversed) {
      final path = Path()..moveTo(0, mid);
      for (var x = 0.0; x <= size.width; x += 3) {
        final t = x / size.width;
        // Fades out at both ends.
        final envelope = math.sin(math.pi * t);
        final y =
            mid +
            height *
                share *
                envelope *
                math.sin(2 * math.pi * lengths * t + phase * speed * 2);
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(WavesPainter old) =>
      old.level != level || old.phase != phase;
}
