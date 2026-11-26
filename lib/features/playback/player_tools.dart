import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/bookmark_repository.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Bookmarks, jump to time, the statistics overlay and the decoder switch
/// (task 8.8: from PotPlayer, IINA, mpv's stats and MX Player).

// ------------------------------------------------------------- bookmarks

abstract final class BookmarkActions {
  /// Bookmarks the current position, named after its time.
  static Future<void> add(WidgetRef ref) async {
    final s = ref.read(playerServiceProvider).state;
    final source = s.source;
    if (source == null || !s.isLoaded) return;
    final label = formatDuration(s.position);
    await ref.read(bookmarkRepositoryProvider).add(source, s.position, label);
    ref.read(osdProvider.notifier).show('🔖 $label');
  }
}

/// The current file's bookmarks: jump, rename, delete, add.
Future<void> showBookmarks(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _BookmarksDialog(),
);

class _BookmarksDialog extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final source = ref.watch(
      playbackStateProvider.select((s) => s.value?.source),
    );
    final marks = source == null
        ? const <Bookmark>[]
        : ref.watch(bookmarksProvider(source)).value ?? const <Bookmark>[];
    final repo = ref.read(bookmarkRepositoryProvider);
    return AlertDialog(
      key: const Key('bookmarks-dialog'),
      title: Text(l.bookmarks),
      content: SizedBox(
        width: 420,
        child: marks.isEmpty
            ? Text(
                l.bookmarksEmpty,
                style: const TextStyle(color: KyndrelColors.textSecondary),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final b in marks)
                    ListTile(
                      key: Key('bookmark-${b.label}'),
                      leading: const Icon(
                        Icons.bookmark,
                        color: KyndrelColors.accent,
                      ),
                      title: Text(b.label),
                      subtitle: Text(
                        formatDuration(Duration(milliseconds: b.positionMs)),
                      ),
                      onTap: () {
                        unawaited(
                          ref
                              .read(playerServiceProvider)
                              .seek(Duration(milliseconds: b.positionMs)),
                        );
                        Navigator.pop(context);
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.libraryRename,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final name = await _askLabel(context, b.label);
                              if (name != null && name.trim().isNotEmpty) {
                                await repo.rename(b.id, name.trim());
                              }
                            },
                          ),
                          IconButton(
                            key: Key('bookmark-delete-${b.label}'),
                            tooltip: l.libraryDelete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => unawaited(repo.remove(b.id)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('bookmark-add'),
          onPressed: () => unawaited(BookmarkActions.add(ref)),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(l.bookmarkAdd),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

Future<String?> _askLabel(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (_) =>
          _TextPrompt(title: context.l10n.libraryRename, initial: current),
    );

// ---------------------------------------------------------- jump to time

/// What the user typed as a time: `1:02:03`, `83:10`, `90` (seconds) or
/// `50%`; null when it isn't one. Clamped to [duration] when known.
Duration? parseTimeInput(String text, {Duration? duration}) {
  final t = text.trim();
  if (t.isEmpty) return null;
  Duration? d;
  if (t.endsWith('%')) {
    final pct = double.tryParse(t.substring(0, t.length - 1).trim());
    if (pct == null || duration == null) return null;
    d = duration * (pct.clamp(0, 100) / 100);
  } else {
    final parts = t.split(':');
    if (parts.length > 3) return null;
    var seconds = 0.0;
    for (final part in parts) {
      final v = double.tryParse(part.trim());
      if (v == null || v < 0) return null;
      seconds = seconds * 60 + v;
    }
    d = Duration(milliseconds: (seconds * 1000).round());
  }
  if (duration != null && duration > Duration.zero && d > duration) {
    return duration;
  }
  return d;
}

Future<void> showJumpToTime(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(title: l.jumpToTime, hint: l.jumpToTimeHint),
  );
  if (text == null) return;
  final s = ref.read(playerServiceProvider).state;
  final at = parseTimeInput(text, duration: s.duration);
  if (at == null) return;
  await ref.read(playerServiceProvider).seek(at);
  ref.read(osdProvider.notifier).show(formatDuration(at));
}

class _TextPrompt extends StatefulWidget {
  const new({required this.title, this.initial = '', this.hint});

  final String title;
  final String initial;
  final String? hint;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('prompt-text'),
      controller: _text,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        key: const Key('prompt-ok'),
        onPressed: () => Navigator.pop(context, _text.text),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}

// ------------------------------------------------------- statistics, decoder

/// The statistics overlay, toggled with Shift+I (mpv's stats, task 8.8).
class StatsOverlayController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final statsOverlayProvider = NotifierProvider<StatsOverlayController, bool>(
  StatsOverlayController.new,
);

/// MX Player's HW / HW+ / SW: hardware decoding, hardware with a copy back
/// (works with every filter), software.
abstract final class DecoderActions {
  static const cycle = ['auto-safe', 'auto-copy', 'no'];

  static String label(String hwdec) => switch (hwdec) {
    'no' => 'SW',
    'auto-copy' || 'mediacodec-copy' => 'HW+',
    _ => 'HW',
  };

  /// The next of HW → HW+ → SW.
  static void next(WidgetRef ref) {
    final now = ref.read(settingsProvider).hwdec;
    final i = cycle.indexOf(now);
    final next = cycle[(i + 1) % cycle.length];
    updateSettings(ref, (s) => s.copyWith(hwdec: next));
    ref.read(osdProvider.notifier).show('${label(next)} ⚙');
  }
}

/// "HW" / "HW+" / "SW" in the top bar; a tap switches.
class DecoderButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hwdec = ref.watch(settingsProvider.select((s) => s.hwdec));
    return Tooltip(
      message: context.l10n.decoderTooltip,
      child: InkWell(
        key: const Key('decoder-button'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => DecoderActions.next(ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: KyndrelColors.trackBuffered),
            borderRadius: BorderRadius.circular(KyndrelTokens.badgeRadius),
          ),
          child: Text(
            DecoderActions.label(hwdec),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
