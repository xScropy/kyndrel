import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/subtitles/subtitle_file.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Every line of the subtitle file being shown, like IINA's subtitle list
/// (task 8.8): the current one highlighted, a tap jumps there, and a line
/// can be copied. Works for subtitle files (external tracks).
Future<void> showSubtitleLines(BuildContext context, WidgetRef ref) {
  final tracks = ref.read(playerServiceProvider).tracks;
  final active = tracks.subtitles
      .where((t) => t.id == tracks.subtitleId)
      .firstOrNull;
  final path = active?.externalFilename;
  List<Cue>? cues;
  if (path != null && File(path).existsSync()) {
    try {
      // Subtitle files are small, and this is a click: read at once.
      cues = parseSubtitles(
        File(path).readAsStringSync(),
        extension: p.extension(path),
      );
    } on Object {
      cues = null;
    }
  }
  return showDialog<void>(
    context: context,
    builder: (_) => _LinesDialog(cues: cues),
  );
}

class _LinesDialog extends ConsumerStatefulWidget {
  const new({required this.cues});

  final List<Cue>? cues;

  @override
  ConsumerState<_LinesDialog> createState() => _LinesDialogState();
}

class _LinesDialogState extends ConsumerState<_LinesDialog> {
  static const rowHeight = 64.0;
  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cues = widget.cues;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final delay = ref.watch(
      trackStateProvider.select((t) => t.value?.subtitleDelay ?? Duration.zero),
    );
    // Lines show `delay` later than written.
    final at = position - delay;
    final current = cues == null
        ? -1
        : cues.indexWhere((c) => c.start <= at && at < c.end);
    if (!_scrolled && current > 2 && cues != null) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo((current - 2) * rowHeight);
      });
    }
    return AlertDialog(
      key: const Key('subtitle-lines'),
      title: Text(l.subtitleLines),
      content: SizedBox(
        width: 520,
        height: 420,
        child: cues == null || cues.isEmpty
            ? Center(
                child: Text(
                  l.subtitleLinesUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KyndrelColors.textSecondary),
                ),
              )
            : ListView.builder(
                controller: _scroll,
                itemExtent: rowHeight,
                itemCount: cues.length,
                itemBuilder: (context, i) {
                  final c = cues[i];
                  return ListTile(
                    key: Key('line-$i'),
                    selected: i == current,
                    selectedTileColor: KyndrelColors.rowActive,
                    leading: Text(
                      formatDuration(c.start),
                      style: const TextStyle(
                        color: KyndrelColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    title: Text(
                      c.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => unawaited(
                      ref.read(playerServiceProvider).seek(c.start + delay),
                    ),
                    trailing: IconButton(
                      key: Key('line-copy-$i'),
                      tooltip: l.copy,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => unawaited(
                        Clipboard.setData(ClipboardData(text: c.text)),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
