/// How a volume of 0–max % maps onto a slider (task 9.1, as in Harbor):
/// 0–100 % takes the first [normalFraction] of the track, so the normal
/// range stays easy to set; the boost above 100 % takes the rest.
abstract final class VolumeScale {
  /// Where 100 % sits on the track.
  static const normalFraction = 0.64;

  /// Values this close to 100 % snap to it, and below [zeroSnap] to 0.
  static const unitySnap = 6.0;
  static const zeroSnap = 3.0;

  /// Position (0–1) of [volume] % on a track that ends at [max] %.
  static double fraction(double volume, double max) {
    final v = volume.clamp(0, max).toDouble();
    if (max <= 100) return v / max;
    if (v <= 100) return v / 100 * normalFraction;
    return normalFraction + (v - 100) / (max - 100) * (1 - normalFraction);
  }

  /// The volume % at [fraction] (0–1) of a track that ends at [max] %,
  /// rounded to a whole percent and snapped to 0 and 100.
  static double valueAt(double fraction, double max) {
    final f = fraction.clamp(0.0, 1.0);
    double v;
    if (max <= 100) {
      v = f * max;
    } else if (f <= normalFraction) {
      v = f / normalFraction * 100;
    } else {
      v = 100 + (f - normalFraction) / (1 - normalFraction) * (max - 100);
    }
    v = v.roundToDouble();
    if ((v - 100).abs() < unitySnap && max > 100) return 100;
    if (v < zeroSnap) return 0;
    return v.clamp(0, max).toDouble();
  }

  /// How far into the boost [volume] is: 0 at 100 % or below, 1 at [max].
  static double boostAmount(double volume, double max) =>
      max <= 100 || volume <= 100
      ? 0
      : ((volume - 100) / (max - 100)).clamp(0.0, 1.0);
}
