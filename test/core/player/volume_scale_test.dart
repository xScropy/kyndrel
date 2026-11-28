import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/volume_scale.dart';

/// Task 9.1: Harbor's volume scale, up to 500 %.
void main() {
  test('100 % sits at 64 % of the track; the boost takes the rest', () {
    expect(VolumeScale.fraction(0, 500), 0);
    expect(VolumeScale.fraction(50, 500), closeTo(0.32, 1e-9));
    expect(VolumeScale.fraction(100, 500), closeTo(0.64, 1e-9));
    expect(VolumeScale.fraction(300, 500), closeTo(0.82, 1e-9));
    expect(VolumeScale.fraction(500, 500), 1);
    expect(VolumeScale.fraction(900, 500), 1);
    // A 200 % limit stretches the boost over the same 36 %.
    expect(VolumeScale.fraction(150, 200), closeTo(0.82, 1e-9));
    // No boost: a plain 0–100 track.
    expect(VolumeScale.fraction(50, 100), 0.5);
  });

  test('positions back to volumes, snapped to 0 and 100', () {
    for (final v in [10.0, 64.0, 150.0, 333.0, 500.0]) {
      expect(VolumeScale.valueAt(VolumeScale.fraction(v, 500), 500), v);
    }
    expect(VolumeScale.valueAt(0.62, 500), 100);
    expect(VolumeScale.valueAt(0.643, 500), 100);
    expect(VolumeScale.valueAt(0.66, 500), 122);
    expect(VolumeScale.valueAt(0.01, 500), 0);
    expect(VolumeScale.valueAt(2, 500), 500);
  });

  test('the boost colour goes from orange to red', () {
    expect(VolumeScale.boostAmount(100, 500), 0);
    expect(VolumeScale.boostAmount(300, 500), 0.5);
    expect(VolumeScale.boostAmount(500, 500), 1);
    expect(KyndrelColors.boost(0), KyndrelColors.boostLow);
    expect(KyndrelColors.boost(1), KyndrelColors.boostHigh);
  });
}
