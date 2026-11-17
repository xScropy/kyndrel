import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_video_view.dart';
import 'package:kyndrel/features/playback/widgets/diagnostics_overlay.dart';
import 'package:kyndrel/features/playback/widgets/open_source_prompt.dart';
import 'package:material_ui/material_ui.dart';

/// The main playback screen. Controls are added task by task in Phase 1.
class PlayerScreen extends ConsumerStatefulWidget {
  const new({
    this.initialSource,
    this.showDiagnostics = false,
    this.titleBar,
    super.key,
  });

  final String? initialSource;
  final bool showDiagnostics;

  /// Window title bar drawn over the top of the video (task 1.2).
  final Widget? titleBar;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    final source = widget.initialSource;
    if (source != null) {
      unawaited(ref.read(playerServiceProvider).open(source));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(playbackStatusProvider).value ?? PlaybackStatus.idle;
    final service = ref.read(playerServiceProvider);

    return Scaffold(
      backgroundColor: KyndrelColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PlayerVideoView(),
          switch (status) {
            PlaybackStatus.idle => Center(
              child: OpenSourcePrompt(onOpen: service.open),
            ),
            PlaybackStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            PlaybackStatus.error => Center(
              child: _ErrorMessage(
                message: service.state.errorMessage ?? '',
                onOpen: service.open,
              ),
            ),
            _ => const SizedBox.shrink(),
          },
          if (widget.showDiagnostics)
            const Positioned(top: 56, right: 12, child: DiagnosticsOverlay()),
          if (widget.titleBar != null)
            Positioned(top: 0, left: 0, right: 0, child: widget.titleBar!),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const new({required this.message, required this.onOpen});

  final String message;
  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: KyndrelColors.error, size: 40),
        const SizedBox(height: 12),
        const Text(
          "Can't play this file",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KyndrelColors.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        OpenSourcePrompt(onOpen: onOpen),
      ],
    );
  }
}
