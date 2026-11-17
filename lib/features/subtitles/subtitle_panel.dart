import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/features/subtitles/subtitle_panel_controller.dart';
import 'package:kyndrel/features/subtitles/subtitle_search_controller.dart';
import 'package:kyndrel/features/subtitles/track_labels.dart';
import 'package:kyndrel/features/subtitles/views/online_results_view.dart';
import 'package:kyndrel/features/subtitles/views/style_view.dart';
import 'package:kyndrel/features/subtitles/views/sync_view.dart';
import 'package:material_ui/material_ui.dart';

/// Subtitles button for the bottom-right group.
class SubtitlesButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      trackStateProvider.select((t) => t.value?.subtitleId != null),
    );
    final open = ref.watch(subtitlePanelProvider) != null;
    return ControlButton(
      key: const Key('subtitles-button'),
      icon: on ? Icons.closed_caption : Icons.closed_caption_off_outlined,
      tooltip: 'Subtitles & audio (S)',
      active: on || open,
      onPressed: ref.read(subtitlePanelProvider.notifier).toggle,
    );
  }
}

/// Two-column panel: tracks on the left, online results / sync / style on
/// the right (tasks 2.4–2.11).
class SubtitlePanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SubtitlePanel> createState() => _SubtitlePanelState();
}

class _SubtitlePanelState extends ConsumerState<SubtitlePanel> {
  late final ControlsVisibility _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(controlsVisibilityProvider.notifier);
    // Providers can't change during build; lock right after this frame.
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
    final view = ref.watch(subtitlePanelProvider) ?? SubtitlePanelView.online;
    final panel = ref.read(subtitlePanelProvider.notifier);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): panel.close},
      child: Focus(
        autofocus: true,
        child: Container(
          key: const Key('subtitle-panel'),
          width: 680,
          height: 440,
          decoration: KyndrelTheme.panelDecoration(),
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          // Material inside the decoration so list tiles paint on top of it.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Subtitles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ControlButton(
                      key: const Key('panel-sync'),
                      icon: Icons.timer_outlined,
                      tooltip: 'Sync offset',
                      active: view == SubtitlePanelView.sync,
                      onPressed: () => panel.show(SubtitlePanelView.sync),
                    ),
                    ControlButton(
                      key: const Key('panel-style'),
                      icon: Icons.tune,
                      tooltip: 'Style',
                      active: view == SubtitlePanelView.style,
                      onPressed: () => panel.show(SubtitlePanelView.style),
                    ),
                    ControlButton(
                      key: const Key('panel-close'),
                      icon: Icons.close,
                      tooltip: 'Close (Esc)',
                      onPressed: panel.close,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 220, child: _TrackColumn()),
                      const VerticalDivider(
                        width: 28,
                        color: KyndrelColors.panelBorder,
                      ),
                      Expanded(
                        child: switch (view) {
                          SubtitlePanelView.online => const OnlineResultsView(),
                          SubtitlePanelView.sync => const SyncView(),
                          SubtitlePanelView.style => const StyleView(),
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: KyndrelColors.panelBorder, height: 16),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackColumn extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(trackStateProvider).value ?? TrackState.empty;
    final service = ref.read(playerServiceProvider);
    return ListView(
      children: [
        const Text('SUBTITLES', style: KyndrelTheme.sectionLabel),
        const SizedBox(height: 6),
        PopoverOption(
          key: const Key('sub-off'),
          label: 'Off',
          selected: tracks.subtitleId == null,
          onTap: () => unawaited(service.selectSubtitle(null)),
        ),
        for (final t in tracks.subtitles)
          _TrackOption(
            key: Key('sub-${t.id}'),
            track: t,
            selected: tracks.subtitleId == t.id,
            onTap: () => unawaited(service.selectSubtitle(t.id)),
          ),
        if (tracks.audio.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('AUDIO', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 6),
          for (final t in tracks.audio)
            _TrackOption(
              key: Key('audio-${t.id}'),
              track: t,
              selected: tracks.audioId == t.id,
              onTap: () => unawaited(service.selectAudioTrack(t.id)),
            ),
        ],
      ],
    );
  }
}

class _TrackOption extends StatelessWidget {
  const new({
    required this.track,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final MediaTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tags = trackTags(track);
    return PopoverOption(
      label: trackLabel(track),
      selected: selected,
      onTap: onTap,
      trailing: tags.isEmpty
          ? null
          : Text(
              tags.join(' · '),
              style: const TextStyle(
                fontSize: 10,
                color: KyndrelColors.sectionLabel,
              ),
            ),
    );
  }
}

class _Footer extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  bool _searching = false;
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: ref.read(subtitleSearchProvider).queryText,
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(subtitlePanelProvider.notifier).open();
    unawaited(
      ref.read(subtitleSearchProvider.notifier).searchText(_query.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_searching)
          Expanded(
            child: TextField(
              key: const Key('subtitle-query'),
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Title, or "Show S01E02"',
              ),
              onSubmitted: (_) => _search(),
            ),
          )
        else
          const Spacer(),
        TextButton.icon(
          key: const Key('find-more'),
          onPressed: () {
            if (_searching) {
              _search();
            } else {
              setState(() => _searching = true);
            }
          },
          icon: const Icon(Icons.search, size: 18),
          label: Text(_searching ? 'Search' : 'Find more subtitles'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const Key('load-file'),
          onPressed: () => unawaited(SubtitleFileActions.loadFile(ref)),
          icon: const Icon(Icons.file_open_outlined, size: 18),
          label: const Text('Load file'),
        ),
      ],
    );
  }
}
