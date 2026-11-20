import 'package:intl/intl.dart';

/// "1.4 GB", "700 MB", "12 KB" (task 7.4).
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit >= 3 && value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// "4K", "1080p", "720p", "480p" from a video's size; null if unknown.
String? resolutionLabel(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  // The short side, and wide films (1920×800 is still 1080p).
  final long = width > height ? width : height;
  final short = width > height ? height : width;
  if (long >= 3800 || short >= 2100) return '4K';
  if (long >= 2500 || short >= 1400) return '1440p';
  if (long >= 1900 || short >= 1000) return '1080p';
  if (long >= 1260 || short >= 700) return '720p';
  if (short >= 470) return '480p';
  return '${short}p';
}

/// A short date in the app's locale ("20 Nov 2026").
String formatDate(DateTime d, String locale) =>
    DateFormat.yMMMd(locale).format(d);
