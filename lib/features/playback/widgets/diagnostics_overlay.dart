import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Live mpv readout (decoder, codec, fps, drops), shown with `--diagnostics`.
/// Used to confirm hardware decoding on a new machine (task 0.5).
class DiagnosticsOverlay extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DiagnosticsOverlay> createState() => _DiagnosticsOverlayState();
}

class _DiagnosticsOverlayState extends ConsumerState<DiagnosticsOverlay> {
  Timer? _timer;
  Map<String, String> _values = const {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    final values = await ref.read(playerServiceProvider).diagnostics();
    if (mounted) setState(() => _values = values);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_values.isEmpty) return const SizedBox.shrink();
    final hwdec = _values['hwdec-current'] ?? 'no';
    final hardware = hwdec.isNotEmpty && hwdec != 'no';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: KyndrelTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DIAGNOSTICS', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          Text(
            hardware ? 'Hardware decoding: $hwdec' : 'Software decoding',
            style: TextStyle(
              color: hardware ? KyndrelColors.accent : KyndrelColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final e in _values.entries)
            Text(
              '${e.key}: ${e.value}',
              style: const TextStyle(
                color: KyndrelColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
