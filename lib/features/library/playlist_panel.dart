import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the queue panel is open.
class PlaylistPanelOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void close() => state = false;
}

final playlistPanelProvider = NotifierProvider<PlaylistPanelOpen, bool>(
  PlaylistPanelOpen.new,
);

class PlaylistButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(playlistProvider.select((s) => s.items.length));
    final open = ref.watch(playlistPanelProvider);
    return ControlButton(
      key: const Key('queue-button'),
      icon: Icons.playlist_play,
      tooltip: count > 1 ? 'Queue · $count (Q)' : 'Queue (Q)',
      active: open,
      onPressed: ref.read(playlistPanelProvider.notifier).toggle,
    );
  }
}

/// Queue with drag-to-reorder, shuffle and repeat (task 3.1).
class PlaylistPanel extends ConsumerStatefulWidget {
  const new({required this.onAddFiles, required this.onOpenFolder, super.key});

  final VoidCallback onAddFiles;
  final VoidCallback onOpenFolder;

  @override
  ConsumerState<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends ConsumerState<PlaylistPanel> {
  late final ControlsVisibility _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(controlsVisibilityProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibility.lock(this);
    });
  }

  @override
  void dispose() {
    _visibility.unlock(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playlistProvider);
    final playlist = ref.read(playlistProvider.notifier);
    final close = ref.read(playlistPanelProvider.notifier).close;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: Focus(
        autofocus: true,
        child: Container(
          key: const Key('playlist-panel'),
          width: 380,
          height: 440,
          decoration: KyndrelTheme.panelDecoration(),
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Queue · ${queue.items.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ControlButton(
                      key: const Key('shuffle'),
                      icon: Icons.shuffle,
                      tooltip: queue.shuffle ? 'Shuffle on' : 'Shuffle off',
                      active: queue.shuffle,
                      onPressed: playlist.toggleShuffle,
                    ),
                    ControlButton(
                      key: const Key('repeat'),
                      icon: queue.repeat == QueueRepeat.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                      tooltip: switch (queue.repeat) {
                        QueueRepeat.off => 'Repeat off',
                        QueueRepeat.all => 'Repeat all',
                        QueueRepeat.one => 'Repeat one',
                      },
                      active: queue.repeat != QueueRepeat.off,
                      onPressed: playlist.cycleRepeat,
                    ),
                    ControlButton(
                      key: const Key('queue-close'),
                      icon: Icons.close,
                      tooltip: 'Close (Esc)',
                      onPressed: close,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: queue.items.isEmpty
                      ? const Center(
                          child: Text(
                            'The queue is empty.',
                            style: TextStyle(
                              color: KyndrelColors.textSecondary,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: queue.items.length,
                          onReorderItem: playlist.reorder,
                          itemBuilder: (context, i) => _QueueTile(
                            key: ValueKey('queue-$i-${queue.items[i]}'),
                            index: i,
                            source: queue.items[i],
                            current: queue.current == i,
                          ),
                        ),
                ),
                const Divider(color: KyndrelColors.panelBorder, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: queue.items.isEmpty ? null : playlist.clear,
                      child: const Text('Clear'),
                    ),
                    TextButton.icon(
                      key: const Key('queue-open-folder'),
                      onPressed: widget.onOpenFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Folder'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      key: const Key('queue-add'),
                      onPressed: widget.onAddFiles,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const new({
    required this.index,
    required this.source,
    required this.current,
    super.key,
  });

  final int index;
  final String source;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = parseMediaTitle(source);
    final playlist = ref.read(playlistProvider.notifier);
    final color = current ? KyndrelColors.accent : KyndrelColors.textPrimary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(playlist.playAt(index)),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: current ? KyndrelColors.rowActive : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: KyndrelColors.sectionLabel,
                  ),
                ),
              ),
              if (current)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.play_arrow,
                    size: 16,
                    color: KyndrelColors.accent,
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color),
                    ),
                    if (t.episode != null || t.year != null)
                      Text(
                        [
                          ?t.episode,
                          if (t.year != null) '${t.year}',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: KyndrelColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                iconSize: 16,
                onPressed: () => playlist.remove(index),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
