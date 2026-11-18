import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Short on-screen message ("Volume 120 %", "Speed 1.25×") shown after a
/// keyboard shortcut or gesture.
class OsdNotifier extends Notifier<String?> {
  static const duration = Duration(milliseconds: 1200);
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String message) {
    try {
      if (!ref.read(settingsProvider).showOsd) return;
    } on Object {
      // No settings (tests): show it.
    }
    state = message;
    _timer?.cancel();
    _timer = Timer(duration, () => state = null);
  }
}

final osdProvider = NotifierProvider<OsdNotifier, String?>(OsdNotifier.new);

class OsdView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(osdProvider);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: message == null ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: message == null
            ? const SizedBox.shrink()
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: KyndrelTheme.panelDecoration(),
                child: Text(
                  message,
                  key: const Key('osd'),
                  style: const TextStyle(
                    color: KyndrelColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

/// What a level OSD shows (task 6.3).
enum LevelKind { brightness, volume }

/// A vertical level bar while swiping brightness or volume.
@immutable
class OsdLevel {
  const new(this.kind, this.value);

  final LevelKind kind;

  /// Brightness 0–1; volume 0–200 (%), the part above 100 being boost.
  final double value;

  double get fraction => switch (kind) {
    LevelKind.brightness => value.clamp(0, 1),
    LevelKind.volume => (value / 200).clamp(0, 1),
  };

  String get label => switch (kind) {
    LevelKind.brightness => '${(value * 100).round()}%',
    LevelKind.volume => '${value.round()}%',
  };

  bool get isBoost => kind == LevelKind.volume && value > 100;

  @override
  bool operator ==(Object other) =>
      other is OsdLevel && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

class LevelOsdNotifier extends Notifier<OsdLevel?> {
  static const hideAfter = Duration(milliseconds: 900);
  Timer? _timer;

  @override
  OsdLevel? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(OsdLevel level) {
    state = level;
    _timer?.cancel();
    _timer = Timer(hideAfter, () => state = null);
  }
}

final levelOsdProvider = NotifierProvider<LevelOsdNotifier, OsdLevel?>(
  LevelOsdNotifier.new,
);

class LevelOsdView extends ConsumerWidget {
  const new({super.key});

  static const height = 168.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelOsdProvider);
    if (level == null) return const SizedBox.shrink();
    final icon = switch (level.kind) {
      LevelKind.brightness => Icons.brightness_6,
      LevelKind.volume when level.value == 0 => Icons.volume_off,
      LevelKind.volume => Icons.volume_up,
    };
    return IgnorePointer(
      child: Container(
        key: const Key('level-osd'),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: KyndrelTheme.panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              level.label,
              key: const Key('level-osd-value'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: level.isBoost
                    ? KyndrelColors.accent
                    : KyndrelColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 8,
              height: height,
              child: CustomPaint(painter: _LevelPainter(level)),
            ),
            const SizedBox(height: 10),
            Icon(icon, size: 22, color: KyndrelColors.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  new(this.level);

  final OsdLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = KyndrelColors.track,
    );
    final top = size.height * (1 - level.fraction);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, top, size.width, size.height),
        r,
      ),
      Paint()
        ..color = level.isBoost
            ? KyndrelColors.accent
            : KyndrelColors.textPrimary,
    );
    if (level.kind == LevelKind.volume) {
      // 100 %: where the phone's volume ends and the boost begins.
      final mid = size.height / 2;
      canvas.drawLine(
        Offset(-3, mid),
        Offset(size.width + 3, mid),
        Paint()
          ..color = KyndrelColors.background
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) => old.level != level;
}
