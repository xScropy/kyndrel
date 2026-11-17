/// `1:02:03` for an hour or more, otherwise `2:03`. Negative durations get
/// a leading minus.
String formatDuration(Duration d) {
  final negative = d.isNegative;
  final total = d.abs().inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  final body = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  return negative ? '-$body' : body;
}

/// Short human form for timers: `1 h 05 min`, `12 min`, `45 s`.
String formatRemaining(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}'
        ' min';
  }
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

/// `1.25×`, `2×`, `0.5×`.
String formatRate(double rate) {
  var s = rate.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '$s×';
}
