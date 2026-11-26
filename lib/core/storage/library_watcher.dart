import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Keeps the library up to date without a manual refresh (task 8.5).
///
/// - Desktop: watches the library folders and every folder with media in
///   it (not recursively: Linux can't watch a tree). A new, deleted or
///   renamed media file or folder rescans after [debounce].
/// - Everywhere: coming back to the app after [staleAfter] rescans
///   (Android has no file events for MediaStore without native code).
class LibraryWatcher {
  new({
    required this.index,
    required this.roots,
    required this.folders,
    required this.desktop,
    this.debounce = const Duration(seconds: 2),
    this.staleAfter = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MediaIndex index;

  /// The library folders the user chose (or the defaults).
  final List<String> roots;

  /// Folders with media in them now.
  final Future<List<String>> Function() folders;
  final bool desktop;
  final Duration debounce;
  final Duration staleAfter;
  final DateTime Function() _now;

  /// Most folders watched: each one costs an OS watch handle.
  static const maxWatched = 256;

  final _subs = <StreamSubscription<FileSystemEvent>>[];
  Timer? _pending;
  StreamSubscription<MediaIndexStatus>? _status;
  AppLifecycleListener? _lifecycle;
  bool _scanning = false;

  int get watching => _subs.length;

  Future<void> start() async {
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    if (!desktop || !FileSystemEntity.isWatchSupported) return;
    // Re-watch after each scan: folders come and go.
    _status = index.statuses.listen((s) {
      if (_scanning && !s.scanning) unawaited(_watchAll());
      _scanning = s.scanning;
    });
    await _watchAll();
  }

  void _onResume() {
    final last = index.status.lastScan;
    if (last == null || _now().difference(last) >= staleAfter) {
      unawaited(index.refresh());
    }
  }

  Future<void> _watchAll() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final dirs = <String>{
      ...roots,
      ...await folders(),
    }.where((d) => Directory(d).existsSync()).take(maxWatched);
    for (final d in dirs) {
      try {
        _subs.add(Directory(d).watch().listen(_onEvent, onError: (_) {}));
      } on FileSystemException {
        // Gone, or out of watch handles: the next scan sees it anyway.
      }
    }
  }

  void _onEvent(FileSystemEvent e) {
    if (!_matters(e)) return;
    _pending?.cancel();
    _pending = Timer(debounce, () => unawaited(index.refresh()));
  }

  /// Media files, subtitle files and folders: what changes the library.
  static bool _matters(FileSystemEvent e) {
    if (p.basename(e.path).startsWith('.') &&
        p.basename(e.path) != '.nomedia') {
      return false;
    }
    if (e.isDirectory) return true;
    final ext = p.extension(e.path).toLowerCase().replaceFirst('.', '');
    return FolderMediaScanner.kindOf(e.path) != null ||
        FolderMediaScanner.subtitleExtensions.contains(ext) ||
        p.basename(e.path) == '.nomedia';
  }

  Future<void> dispose() async {
    _pending?.cancel();
    _lifecycle?.dispose();
    await _status?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}

final libraryWatcherProvider = Provider<LibraryWatcher>((ref) {
  final db = ref.watch(databaseProvider);
  final configured = ref.watch(
    settingsProvider.select((s) => s.libraryFolders),
  );
  final watcher = LibraryWatcher(
    index: ref.watch(mediaIndexProvider),
    roots: configured.isEmpty
        ? FolderMediaScanner.defaultFolders()
        : configured,
    folders: () async {
      final q = db.selectOnly(db.libraryItems, distinct: true)
        ..addColumns([db.libraryItems.folderPath]);
      return [
        for (final r in await q.get()) ?r.read(db.libraryItems.folderPath),
      ];
    },
    desktop: !Platform.isAndroid && !Platform.isIOS,
  );
  unawaited(watcher.start());
  ref.onDispose(watcher.dispose);
  return watcher;
});
