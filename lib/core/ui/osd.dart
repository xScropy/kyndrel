import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
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
