import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/features/playback/widgets/open_source_prompt.dart';
import 'package:material_ui/material_ui.dart';

/// Centre of the screen: open prompt when idle, spinner while loading or
/// buffering, and the "can't play" message with mpv's log (task 1.13).
class StatusLayer extends ConsumerWidget {
  const new({required this.onPickFile, super.key});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(playbackStatusProvider).value ?? PlaybackStatus.idle;
    final buffering = ref.watch(bufferingProvider).value ?? false;
    final service = ref.read(playerServiceProvider);
    final open = ref.read(playlistProvider.notifier).open;

    return switch (status) {
      PlaybackStatus.idle => Center(
        child: OpenSourcePrompt(onOpen: open, onPickFile: onPickFile),
      ),
      PlaybackStatus.loading => const Center(
        child: CircularProgressIndicator(key: Key('loading')),
      ),
      PlaybackStatus.error => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _ErrorMessage(
              message: service.state.errorMessage ?? '',
              log: service.logExcerpt(),
              onOpen: open,
              onPickFile: onPickFile,
            ),
          ),
        ),
      ),
      _ when buffering => const IgnorePointer(
        child: Center(child: CircularProgressIndicator(key: Key('buffering'))),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ErrorMessage extends StatelessWidget {
  const new({
    required this.message,
    required this.log,
    required this.onOpen,
    required this.onPickFile,
  });

  final String message;
  final String log;
  final Future<void> Function(String) onOpen;
  final VoidCallback onPickFile;

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
        if (log.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('error-log'),
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KyndrelColors.panelBorder),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 32),
                  child: SelectableText(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: KyndrelColors.textSecondary,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Copy log',
                    iconSize: 16,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: '$message\n$log'),
                    ),
                    icon: const Icon(Icons.copy),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        OpenSourcePrompt(onOpen: onOpen, onPickFile: onPickFile),
      ],
    );
  }
}
