import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/features/subtitles/track_labels.dart';
import 'package:material_ui/material_ui.dart';

/// Subtitle and audio sync offsets plus the secondary subtitle
/// (tasks 2.7, 2.11).
class SyncView extends ConsumerWidget {
  const new({super.key});

  static const step = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(trackStateProvider).value ?? TrackState.empty;
    final service = ref.read(playerServiceProvider);
    return ListView(
      children: [
        const Text('SUBTITLE DELAY', style: KyndrelTheme.sectionLabel),
        DelayEditor(
          key: const Key('sub-delay'),
          value: tracks.subtitleDelay,
          onChanged: (d) => unawaited(service.setSubtitleDelay(d)),
          help: 'Positive shows subtitles later.',
        ),
        const SizedBox(height: 16),
        const Text('AUDIO DELAY', style: KyndrelTheme.sectionLabel),
        DelayEditor(
          key: const Key('audio-delay'),
          value: tracks.audioDelay,
          onChanged: (d) => unawaited(service.setAudioDelay(d)),
          help: 'Positive plays audio later.',
        ),
        const SizedBox(height: 16),
        const Text('SECONDARY SUBTITLE', style: KyndrelTheme.sectionLabel),
        const SizedBox(height: 6),
        DropdownButton<int?>(
          key: const Key('secondary-sid'),
          isExpanded: true,
          value: tracks.secondarySubtitleId,
          dropdownColor: KyndrelColors.surface,
          items: [
            const DropdownMenuItem(child: Text('Off')),
            for (final t in tracks.subtitles.where((t) => !t.isImageSubtitle))
              DropdownMenuItem(value: t.id, child: Text(trackLabel(t))),
          ],
          onChanged: (id) => unawaited(service.selectSecondarySubtitle(id)),
        ),
        const Text(
          'Shown at the top of the picture, for two languages at once.',
          style: TextStyle(fontSize: 11, color: KyndrelColors.textSecondary),
        ),
      ],
    );
  }
}

/// −/+ buttons, a numeric field in seconds and reset.
class DelayEditor extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.help,
    super.key,
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final String? help;

  @override
  State<DelayEditor> createState() => _DelayEditorState();
}

class _DelayEditorState extends State<DelayEditor> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();

  static String _format(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);

  @override
  void didUpdateWidget(DelayEditor old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final s = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (s == null) {
      _controller.text = _format(widget.value);
      return;
    }
    widget.onChanged(Duration(milliseconds: (s * 1000).round()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('delay-minus'),
              tooltip: '−0.1 s',
              onPressed: () => widget.onChanged(widget.value - SyncView.step),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                key: const Key('delay-field'),
                controller: _controller,
                focusNode: _focus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: 's',
                ),
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) {
                  if (_focus.hasFocus) {
                    _submit();
                    _focus.unfocus();
                  }
                },
              ),
            ),
            IconButton(
              key: const Key('delay-plus'),
              tooltip: '+0.1 s',
              onPressed: () => widget.onChanged(widget.value + SyncView.step),
              icon: const Icon(Icons.add),
            ),
            TextButton(
              onPressed: widget.value == Duration.zero
                  ? null
                  : () => widget.onChanged(Duration.zero),
              child: const Text('Reset'),
            ),
          ],
        ),
        if (widget.help != null)
          Text(
            widget.help!,
            style: const TextStyle(
              fontSize: 11,
              color: KyndrelColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
