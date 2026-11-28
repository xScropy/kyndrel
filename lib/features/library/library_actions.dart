import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/file_actions.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/library_repository.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:kyndrel/features/library/library_playlists.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The header while videos are selected (task 8.6): how many, select all,
/// play, queue, add to a playlist, and file actions.
class SelectionBar extends ConsumerWidget {
  const new({required this.all, super.key});

  /// The videos shown, in order ("select all", and the order things play).
  final List<LibraryItem> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(videoLibraryProvider);
    final c = ref.read(videoLibraryProvider.notifier);
    final selected = [
      for (final i in all)
        if (view.selection.contains(i.uri)) i,
    ];
    final uris = [for (final i in selected) i.uri];
    final files = ref.read(fileActionsProvider);
    return Padding(
      key: const Key('library-selection'),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('selection-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: c.clearSelection,
          ),
          Expanded(
            child: Text(
              l.librarySelected(view.selection.length),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            key: const Key('selection-all'),
            tooltip: l.librarySelectAll,
            icon: const Icon(Icons.select_all),
            onPressed: () => c.selectAll(all.map((i) => i.uri)),
          ),
          IconButton(
            key: const Key('selection-play'),
            tooltip: l.libraryPlay,
            icon: const Icon(Icons.play_arrow),
            onPressed: uris.isEmpty
                ? null
                : () {
                    c.clearSelection();
                    unawaited(
                      ref.read(playlistProvider.notifier).openAll(uris),
                    );
                  },
          ),
          IconButton(
            key: const Key('selection-queue'),
            tooltip: l.libraryEnqueue,
            icon: const Icon(Icons.queue),
            onPressed: uris.isEmpty
                ? null
                : () {
                    c.clearSelection();
                    unawaited(
                      ref.read(playlistProvider.notifier).enqueue(uris),
                    );
                  },
          ),
          IconButton(
            key: const Key('selection-playlist'),
            tooltip: l.libraryAddToPlaylist,
            icon: const Icon(Icons.playlist_add),
            onPressed: uris.isEmpty
                ? null
                : () => unawaited(addToPlaylistDialog(context, ref, uris)),
          ),
          PopupMenuButton<String>(
            key: const Key('selection-more'),
            onSelected: (v) => unawaited(_act(context, ref, v, selected)),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('selection-watched'),
                value: 'watched',
                child: Text(l.libraryMarkWatched),
              ),
              PopupMenuItem(
                key: const Key('selection-unwatched'),
                value: 'unwatched',
                child: Text(l.libraryMarkUnwatched),
              ),
              if (files.supported && _localFiles(selected)) ...[
                const PopupMenuDivider(),
                if (selected.length == 1)
                  PopupMenuItem(
                    key: const Key('selection-rename'),
                    value: 'rename',
                    child: Text(l.libraryRename),
                  ),
                PopupMenuItem(
                  key: const Key('selection-move'),
                  value: 'move',
                  child: Text(l.libraryMove),
                ),
                PopupMenuItem(
                  key: const Key('selection-delete'),
                  value: 'delete',
                  child: Text(l.libraryDelete),
                ),
              ],
              if (selected.length == 1) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: const Key('selection-details'),
                  value: 'details',
                  child: Text(l.libraryDetails),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// File actions need real paths (not Android `content://` items).
  static bool _localFiles(List<LibraryItem> items) =>
      items.isNotEmpty && items.every((i) => !i.uri.contains('://'));

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String action,
    List<LibraryItem> items,
  ) async {
    final l = context.l10n;
    final c = ref.read(videoLibraryProvider.notifier);
    final repo = ref.read(libraryRepositoryProvider);
    final files = ref.read(fileActionsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uris = [for (final i in items) i.uri];
    void failed(String name) => messenger?.showSnackBar(
      SnackBar(content: Text(l.libraryActionFailed(name))),
    );

    switch (action) {
      case 'watched':
        await repo.setWatched(uris, watched: true);
      case 'unwatched':
        await repo.setWatched(uris, watched: false);
        final history = ref.read(historyRepositoryProvider);
        for (final u in uris) {
          await history.remove(u);
        }
      case 'details':
        if (context.mounted) await showVideoDetails(context, ref, items.single);
        return;
      case 'rename':
        final item = items.single;
        final name = await _askText(
          context,
          title: l.libraryRename,
          initial: item.name,
        );
        if (name == null || name == item.name) return;
        try {
          await files.rename(item.uri, name);
          await repo.forget([item.uri]);
        } on Object {
          failed(item.name);
        }
      case 'move':
        final folder = await getDirectoryPath();
        if (folder == null) return;
        for (final i in items) {
          try {
            await files.move(i.uri, folder);
            await repo.forget([i.uri]);
          } on Object {
            failed(i.name);
          }
        }
      case 'delete':
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l.libraryDeleteConfirm(items.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const Key('delete-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.libraryDelete),
              ),
            ],
          ),
        );
        if (ok != true) return;
        for (final i in items) {
          try {
            await files.trash(i.uri);
            await repo.forget([i.uri]);
          } on Object {
            failed(i.name);
          }
        }
    }
    c.clearSelection();
    if (action == 'rename' || action == 'move' || action == 'delete') {
      unawaited(ref.read(mediaIndexProvider).refresh());
    }
  }
}

/// Asks for a line of text; null when cancelled.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  String initial = '',
  bool digits = false,
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextDialog(
    title: title,
    initial: initial,
    digits: digits,
    obscure: obscure,
  ),
);

/// Owns its text controller, so it lives as long as the dialog (closing
/// animation included).
class _TextDialog extends StatefulWidget {
  const new({
    required this.title,
    required this.initial,
    required this.digits,
    required this.obscure,
  });

  final String title;
  final String initial;
  final bool digits;
  final bool obscure;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
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
      key: const Key('ask-text'),
      controller: _text,
      autofocus: true,
      obscureText: widget.obscure,
      keyboardType: widget.digits ? TextInputType.number : null,
      inputFormatters: widget.digits
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ]
          : null,
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        key: const Key('ask-ok'),
        onPressed: () => Navigator.pop(context, _text.text),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}

/// Adds [uris] to a saved playlist, or a new one.
Future<void> addToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> uris,
) async {
  final l = context.l10n;
  final repo = ref.read(libraryRepositoryProvider);
  final choice = await showDialog<int>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final lists = ref.watch(savedPlaylistsProvider).value ?? const [];
        return SimpleDialog(
          key: const Key('add-to-playlist'),
          title: Text(l.libraryAddToPlaylist),
          children: [
            SimpleDialogOption(
              key: const Key('playlist-new'),
              onPressed: () => Navigator.pop(context, -1),
              child: Row(
                children: [
                  const Icon(Icons.add, color: KyndrelColors.accent),
                  const SizedBox(width: 12),
                  Text(l.libraryNewPlaylist),
                ],
              ),
            ),
            for (final (p, n) in lists)
              SimpleDialogOption(
                key: Key('playlist-${p.name}'),
                onPressed: () => Navigator.pop(context, p.id),
                child: Text('${p.name} · $n'),
              ),
          ],
        );
      },
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == -1) {
    final name = await _askText(context, title: l.libraryPlaylistName);
    if (name == null || name.trim().isEmpty) return;
    await repo.createPlaylist(name.trim(), uris);
  } else {
    await repo.addToPlaylist(choice, uris);
  }
  ref.read(videoLibraryProvider.notifier).clearSelection();
}

/// Rename / delete a saved playlist.
Future<String?> askPlaylistName(BuildContext context, String current) =>
    _askText(context, title: context.l10n.playlistRename, initial: current);

String _pinHash(String pin) => fnv1a64('kyndrel-pin:$pin');

/// Opens (asking for the PIN, or choosing one the first time) or locks
/// the private folders (task 8.6).
Future<void> togglePrivateFolders(BuildContext context, WidgetRef ref) async {
  final c = ref.read(videoLibraryProvider.notifier);
  if (ref.read(videoLibraryProvider).unlocked) {
    c.setUnlocked(value: false);
    return;
  }
  if (await askPin(context, ref)) c.setUnlocked(value: true);
}

/// True when the right PIN was given, or a new one chosen.
Future<bool> askPin(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final saved = ref.read(settingsProvider).privatePin;
  if (saved.isEmpty) {
    final pin = await _askText(
      context,
      title: l.librarySetPin,
      digits: true,
      obscure: true,
    );
    if (pin == null || pin.length < 4) return false;
    updateSettings(ref, (s) => s.copyWith(privatePin: _pinHash(pin)));
    return true;
  }
  if (!context.mounted) return false;
  final pin = await _askText(
    context,
    title: l.libraryPinTitle,
    digits: true,
    obscure: true,
  );
  if (pin == null) return false;
  if (_pinHash(pin) == saved) return true;
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l.libraryWrongPin)));
  }
  return false;
}

/// Pin, hide, make private, play all or shuffle a folder (task 8.6).
Future<void> showFolderActions(
  BuildContext context,
  WidgetRef ref,
  FolderSummary folder,
  List<LibraryItem>? items,
) async {
  final l = context.l10n;
  final repo = ref.read(libraryRepositoryProvider);
  Future<List<String>> uris() async => [
    for (final i
        in items ??
            await repo
                .watchItems(
                  MediaKind.video,
                  folder: folder.path,
                  sort: LibrarySort.name,
                  descending: false,
                )
                .first)
      i.uri,
  ];
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: KyndrelColors.panel,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
      child: Column(
        key: const Key('folder-actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              folder.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(folder.path),
          ),
          for (final (key, icon, label) in [
            ('play', Icons.play_arrow, l.libraryPlayAll),
            ('shuffle', Icons.shuffle, l.libraryShuffle),
            (
              'pin',
              folder.pinned ? Icons.push_pin_outlined : Icons.push_pin,
              folder.pinned ? l.libraryUnpin : l.libraryPin,
            ),
            (
              'hide',
              folder.hidden ? Icons.visibility : Icons.visibility_off,
              folder.hidden ? l.libraryUnhide : l.libraryHide,
            ),
            (
              'private',
              folder.private ? Icons.lock_open : Icons.lock,
              folder.private ? l.libraryMakePublic : l.libraryMakePrivate,
            ),
          ])
            ListTile(
              key: Key('folder-action-$key'),
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, key),
            ),
        ],
      ),
    ),
  );
  switch (action) {
    case 'play':
      unawaited(ref.read(playlistProvider.notifier).openAll(await uris()));
    case 'shuffle':
      final list = await uris()
        ..shuffle(math.Random());
      unawaited(ref.read(playlistProvider.notifier).openAll(list));
    case 'pin':
      await repo.setFolder(folder.path, pinned: !folder.pinned);
    case 'hide':
      await repo.setFolder(folder.path, hidden: !folder.hidden);
    case 'private':
      // Changing what is private needs the PIN (or choosing one).
      if (!context.mounted || !await askPin(context, ref)) return;
      await repo.setFolder(folder.path, private: !folder.private);
      ref.read(videoLibraryProvider.notifier).back();
  }
}
