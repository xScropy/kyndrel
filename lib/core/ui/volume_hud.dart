import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/volume_scale.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Harbor's volume panel (task 9.1): a glass card with the speaker, VOLUME
/// and the percentage over a bar that thickens and turns orange to red
/// while boosting, with a tick at 100 %.
class VolumeHud extends ConsumerWidget {
  const new({super.key});

  static const width = 256.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(volumeHudProvider);
    final (volume, isMuted) = ref.watch(
      playbackStateProvider.select(
        (s) => (s.value?.volume ?? 100, s.value?.isMuted ?? false),
      ),
    );
    final max = ref.watch(settingsProvider.select((s) => s.volumeBoostMax));
    final v = volume.clamp(0.0, max);
    final muted = isMuted || v <= 0;
    final boost = muted ? 0.0 : VolumeScale.boostAmount(v, max);
    final boosting = boost > 0;
    final color = boosting
        ? KyndrelColors.boost(boost)
        : KyndrelColors.textPrimary;
    final l = context.l10n;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          key: const Key('volume-hud'),
          width: width,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
          decoration: BoxDecoration(
            color: KyndrelColors.glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KyndrelColors.glassBorder),
            boxShadow: const [
              BoxShadow(
                color: KyndrelColors.titleBarScrim,
                blurRadius: 40,
                offset: Offset(0, 22),
                spreadRadius: -22,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  muted
                      ? Icons.volume_off
                      : v < 50
                      ? Icons.volume_down
                      : Icons.volume_up,
                  key: ValueKey((muted, v < 50, boosting)),
                  size: 26,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            l.volume.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.5,
                              color: KyndrelColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          muted ? l.volumeMuted : '${v.round()}%',
                          key: const Key('volume-hud-value'),
                          style: TextStyle(
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: const Cubic(0.34, 1.56, 0.64, 1),
                      height: boosting ? 16 : 10,
                      child: CustomPaint(
                        painter: _HudBarPainter(
                          fraction: muted ? 0 : VolumeScale.fraction(v, max),
                          color: color,
                          tick: max > 100
                              ? VolumeScale.fraction(100, max)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudBarPainter extends CustomPainter {
  new({required this.fraction, required this.color, this.tick});

  final double fraction;
  final Color color;
  final double? tick;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final all = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas
      ..drawRRect(all, Paint()..color = KyndrelColors.titleBarScrim)
      ..drawRRect(
        all,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = KyndrelColors.glassBorder,
      );
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * fraction, size.height),
          r,
        ),
        Paint()..color = color,
      );
    }
    if (tick case final t?) {
      final x = size.width * t;
      canvas.drawRect(
        Rect.fromLTWH(x, -2, 1, size.height + 4),
        Paint()..color = KyndrelColors.trackBuffered,
      );
    }
  }

  @override
  bool shouldRepaint(_HudBarPainter old) =>
      old.fraction != fraction || old.color != color || old.tick != tick;
}
