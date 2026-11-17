import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/features/speed_sleep/speed_options.dart';

void main() {
  test('labels', () {
    expect(SpeedOptions.label(1), 'Normal');
    expect(SpeedOptions.label(1.25), '1.25×');
    expect(SpeedOptions.label(2), '2×');
  });

  test('stepping walks the list and stops at the ends', () {
    expect(SpeedOptions.stepUp(1), 1.25);
    expect(SpeedOptions.stepUp(2), 2);
    expect(SpeedOptions.stepDown(1), 0.75);
    expect(SpeedOptions.stepDown(0.5), 0.5);
    // From a custom speed, go to the neighbouring preset.
    expect(SpeedOptions.stepUp(1.1), 1.25);
    expect(SpeedOptions.stepDown(1.1), 1);
  });

  test('custom speed parsing', () {
    expect(SpeedOptions.parseCustom('1.1'), 1.1);
    expect(SpeedOptions.parseCustom('1,3x'), 1.3);
    expect(SpeedOptions.parseCustom(' 3 × '), 3);
    expect(SpeedOptions.parseCustom('0.05'), isNull);
    expect(SpeedOptions.parseCustom('5'), isNull);
    expect(SpeedOptions.parseCustom('fast'), isNull);
  });
}
