import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/features/download/download_manager.dart';
import 'package:material_ui/material_ui.dart';

/// Whether yt-dlp is installed (checked once).
final ytDlpAvailableProvider = FutureProvider<bool>(
  (ref) => ref.read(downloadManagerProvider.notifier).hasYtDlp(),
);

/// Bottom-left download button and the downloads popover (task 4.3).
class DownloadButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final running = tasks.where((t) => t.status == DownloadStatus.running);
    return Popover(
      align: PopoverAlign.left,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('download'),
        icon: running.isEmpty ? Icons.download_outlined : Icons.downloading,
        tooltip: 'Download',
        active: running.isNotEmpty,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => const DownloadsPanel(),
    );
  }
}

class DownloadsPanel extends ConsumerWidget {
  const new({super.key});

  static const terms =
      'Only download videos you own, that are openly licensed, or that the '
      'site allows you to save. Kyndrel does not download DRM-protected '
      'streams.';

  Future<void> _downloadCurrent(BuildContext context, WidgetRef ref) async {
    final source = ref.read(playerServiceProvider).state.source;
    if (source == null) return;
    final settings = ref.read(settingsProvider);
    if (!settings.downloadTermsAccepted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Before you download'),
          content: const Text(terms),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('download-agree'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(downloadTermsAccepted: true));
    }
    final folder = settings.downloadFolder.isEmpty
        ? defaultDownloadFolder()
        : settings.downloadFolder;
    await ref.read(downloadManagerProvider.notifier).add(source, folder);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final source = ref.watch(
      playbackStateProvider.select((s) => s.value?.source),
    );
    final ytDlp = ref.watch(ytDlpAvailableProvider).value ?? false;
    final kind = source == null
        ? DownloadKind.none
        : DownloadManager.kindOf(source, hasYtDlp: ytDlp);
    final manager = ref.read(downloadManagerProvider.notifier);

    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DOWNLOADS', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('download-current'),
            onPressed: kind == DownloadKind.none
                ? null
                : () => unawaited(_downloadCurrent(context, ref)),
            icon: const Icon(Icons.download, size: 18),
            label: Text(
              kind == DownloadKind.ytDlp
                  ? 'Download with yt-dlp'
                  : 'Download this video',
            ),
          ),
          if (kind == DownloadKind.none)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                source == null || !source.contains('://')
                    ? 'Downloads are for videos streamed from the web.'
                    : 'This stream can only be saved with yt-dlp installed.',
                key: const Key('download-hint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: KyndrelColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            const Text(
              'Nothing downloaded yet.',
              style: TextStyle(color: KyndrelColors.textSecondary),
            ),
          for (final t in tasks.reversed.take(6))
            _TaskRow(task: t, manager: manager),
          if (tasks.any(
            (t) =>
                t.status == DownloadStatus.done ||
                t.status == DownloadStatus.failed ||
                t.status == DownloadStatus.cancelled,
          ))
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: manager.clearFinished,
                child: const Text('Clear finished'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const new({required this.task, required this.manager});

  final DownloadTask task;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final mb = (t.received / 1e6).toStringAsFixed(1);
    final status = switch (t.status) {
      DownloadStatus.queued => 'Waiting',
      DownloadStatus.running =>
        t.viaYtDlp
            ? '${((t.progress ?? 0) * 100).round()}%'
            : t.total == null
            ? '$mb MB'
            : '$mb / ${(t.total! / 1e6).toStringAsFixed(1)} MB',
      DownloadStatus.paused => 'Paused · $mb MB',
      DownloadStatus.done => 'Done',
      DownloadStatus.failed => t.error ?? 'Failed',
      DownloadStatus.cancelled => 'Cancelled',
    };
    return Padding(
      key: Key('download-${t.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t.status == DownloadStatus.running)
                IconButton(
                  tooltip: 'Pause',
                  iconSize: 18,
                  onPressed: () => manager.pause(t.id),
                  icon: const Icon(Icons.pause),
                ),
              if (t.status == DownloadStatus.paused ||
                  t.status == DownloadStatus.failed)
                IconButton(
                  tooltip: 'Resume',
                  iconSize: 18,
                  onPressed: () => manager.resume(t.id),
                  icon: const Icon(Icons.play_arrow),
                ),
              if (t.status != DownloadStatus.done &&
                  t.status != DownloadStatus.cancelled)
                IconButton(
                  tooltip: 'Cancel',
                  iconSize: 18,
                  onPressed: () => manager.cancel(t.id),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (t.status == DownloadStatus.running ||
              t.status == DownloadStatus.paused)
            LinearProgressIndicator(value: t.progress),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: t.status == DownloadStatus.failed
                  ? KyndrelColors.error
                  : KyndrelColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
