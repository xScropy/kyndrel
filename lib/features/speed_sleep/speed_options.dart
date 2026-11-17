import 'package:kyndrel/core/player/player_service.dart';

/// Speed choices in the popover (task 2.1) and for `[` / `]`.
abstract final class SpeedOptions {
  static const values = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const normal = 1.0;

  static String label(double rate) =>
      rate == normal ? 'Normal' : '${_trim(rate)}×';

  /// Next value above [rate] in [values], or [rate] at the top.
  static double stepUp(double rate) =>
      values.firstWhere((v) => v > rate + 1e-6, orElse: () => values.last);

  /// Next value below [rate] in [values], or [rate] at the bottom.
  static double stepDown(double rate) =>
      values.lastWhere((v) => v < rate - 1e-6, orElse: () => values.first);

  /// Parses a custom speed such as `1.1`, `1,1` or `1.1x`. Null if invalid
  /// or outside [PlayerService.minRate]–[PlayerService.maxRate].
  static double? parseCustom(String text) {
    final cleaned = text
        .trim()
        .toLowerCase()
        .replaceAll(',', '.')
        .replaceAll(RegExp('[x×]'), '')
        .trim();
    final v = double.tryParse(cleaned);
    if (v == null) return null;
    if (v < PlayerService.minRate || v > PlayerService.maxRate) return null;
    return (v * 100).round() / 100;
  }

  static String _trim(double v) => v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
