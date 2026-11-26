import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/frame_engine.dart';
import 'package:kyndrel/core/player/media_prober.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Where the library stands.
@immutable
class MediaIndexStatus {
  const new({
    this.scanning = false,
    this.granted = true,
    this.toProbe = 0,
    this.lastScan,
  });

  final bool scanning;

  /// False when the OS refused access (Android).
  final bool granted;

  /// Files still waiting for details and a thumbnail.
  final int toProbe;
  final DateTime? lastScan;

  MediaIndexStatus copyWith({
    bool? scanning,
    bool? granted,
    int? toProbe,
    DateTime? lastScan,
  }) => MediaIndexStatus(
    scanning: scanning ?? this.scanning,
    granted: granted ?? this.granted,
    toProbe: toProbe ?? this.toProbe,
    lastScan: lastScan ?? this.lastScan,
  );
}

/// The videos and music on this device, kept in the database
/// ([LibraryItems]) so the library opens at once (task 7.3).
///
/// [refresh] scans, adds new files, updates changed ones and drops the
/// gone ones; then details and thumbnails are filled in the background,
/// one file at a time, newest first.
class MediaIndex {
  new({
    required this.db,
    required this.scanner,
    required this.prober,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final KyndrelDatabase db;
  final MediaScanner scanner;
  final MediaProber prober;
  final DateTime Function() _now;

  final _status = StreamController<MediaIndexStatus>.broadcast();
  MediaIndexStatus _current = const MediaIndexStatus();
  bool _probing = false;
  bool _disposed = false;
  Future<void>? _refreshing;

  MediaIndexStatus get status => _current;

  /// The current status first, then each change.
  Stream<MediaIndexStatus> get statuses => Stream.multi((c) {
    c.add(_current);
    final sub = _status.stream.listen(c.addSync, onDone: c.close);
    c.onCancel = sub.cancel;
  });

  void _set(MediaIndexStatus s) {
    _current = s;
    if (!_disposed) _status.add(s);
  }

  /// Every item of [kind], newest first; updates as the index changes.
  Stream<List<LibraryItem>> watch(MediaKind kind) =>
      (db.select(db.libraryItems)
            ..where((t) => t.kind.equals(kind.name))
            ..orderBy([(t) => OrderingTerm.desc(t.added)]))
          .watch();

  /// Scans again. Concurrent calls share one scan.
  Future<void> refresh({bool ask = false}) =>
      _refreshing ??= _refresh(ask: ask).whenComplete(() => _refreshing = null);

  Future<void> _refresh({required bool ask}) async {
    _set(_current.copyWith(scanning: true));
    try {
      if (ask) {
        final granted = await scanner.requestAccess();
        _set(_current.copyWith(granted: granted));
        if (!granted) return;
      }
      final found = await scanner.scan();
      await _reconcile(found);
      _set(_current.copyWith(lastScan: _now()));
    } finally {
      _set(_current.copyWith(scanning: false));
    }
    unawaited(_probeAll());
  }

  Future<void> _reconcile(List<ScannedFile> found) async {
    final existing = {
      for (final i in await db.select(db.libraryItems).get()) i.uri: i,
    };
    final now = _now();
    final keep = <String>{};
    await db.batch((b) {
      for (final f in found) {
        keep.add(f.uri);
        final old = existing[f.uri];
        final changed =
            old == null ||
            old.size != f.size ||
            old.modified.millisecondsSinceEpoch !=
                f.modified.millisecondsSinceEpoch;
        if (!changed) {
          // A subtitle file appeared or went: only that changes.
          if (old.hasSubtitles != f.hasSubtitles) {
            b.update(
              db.libraryItems,
              LibraryItemsCompanion(hasSubtitles: Value(f.hasSubtitles)),
              where: (t) => t.uri.equals(f.uri),
            );
          }
          continue;
        }
        b.insert(
          db.libraryItems,
          LibraryItemsCompanion.insert(
            uri: f.uri,
            name: f.name,
            folder: f.folder,
            folderPath: f.folderPath,
            kind: f.kind.name,
            size: Value(f.size),
            modified: f.modified,
            added: old?.added ?? f.added ?? now,
            durationMs: Value(f.duration?.inMilliseconds),
            width: Value(f.width),
            height: Value(f.height),
            title: Value(f.title),
            artist: Value(f.artist),
            album: Value(f.album),
            trackNo: Value(f.trackNo),
            hasSubtitles: Value(f.hasSubtitles),
            watched: Value(old?.watched ?? false),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      final gone = existing.keys.where((u) => !keep.contains(u)).toList();
      if (gone.isNotEmpty) {
        b.deleteWhere(db.libraryItems, (t) => t.uri.isIn(gone));
      }
    });
  }

  Future<void> _probeAll() async {
    if (_probing) return;
    _probing = true;
    try {
      while (!_disposed) {
        final pending =
            await (db.select(db.libraryItems)
                  ..where((t) => t.probed.equals(false))
                  ..orderBy([(t) => OrderingTerm.desc(t.added)]))
                .get();
        _set(_current.copyWith(toProbe: pending.length));
        if (pending.isEmpty) break;
        await _probe(pending.first);
      }
    } finally {
      _probing = false;
    }
  }

  Future<void> _probe(LibraryItem item) async {
    final kind = item.kind == MediaKind.audio.name
        ? MediaKind.audio
        : MediaKind.video;
    ProbedDetails? details;
    String? thumbnail;
    try {
      details = await prober.probe(item.uri);
      final duration =
          details?.duration ??
          (item.durationMs == null
              ? null
              : Duration(milliseconds: item.durationMs!));
      thumbnail = await prober.thumbnail(
        item.uri,
        kind,
        duration: duration,
        hasCover: details?.hasCover ?? true,
      );
    } on Object {
      // Unreadable: mark it done anyway, so it isn't retried forever.
    }
    if (_disposed) return;
    await (db.update(
      db.libraryItems,
    )..where((t) => t.uri.equals(item.uri))).write(
      LibraryItemsCompanion(
        probed: const Value(true),
        thumbnailPath: Value(thumbnail ?? item.thumbnailPath),
        durationMs: details?.duration == null
            ? const Value.absent()
            : Value(details!.duration!.inMilliseconds),
        width: details?.width == null
            ? const Value.absent()
            : Value(details!.width),
        height: details?.height == null
            ? const Value.absent()
            : Value(details!.height),
        videoCodec: Value(details?.videoCodec ?? item.videoCodec),
        audioCodec: Value(details?.audioCodec ?? item.audioCodec),
        title: Value(details?.title ?? item.title),
        artist: Value(details?.artist ?? item.artist),
        album: Value(details?.album ?? item.album),
        trackNo: Value(details?.trackNo ?? item.trackNo),
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _status.close();
  }
}

/// MediaStore on Android; the library folders elsewhere.
final mediaScannerProvider = Provider<MediaScanner>((ref) {
  if (Platform.isAndroid) return const AndroidMediaScanner();
  final folders = ref.watch(settingsProvider.select((s) => s.libraryFolders));
  return FolderMediaScanner(
    folders.isEmpty ? FolderMediaScanner.defaultFolders() : folders,
  );
});

final mediaProberProvider = Provider<MediaProber>((ref) {
  if (Platform.isAndroid) {
    return AndroidMediaProber(cacheDir: ref.watch(appCacheDirProvider));
  }
  final prober = MpvMediaProber(
    previews: ref.watch(previewSourceProvider),
    engine: ref.watch(frameEngineProvider),
  );
  ref.onDispose(prober.dispose);
  return prober;
});

final mediaIndexProvider = Provider<MediaIndex>((ref) {
  final index = MediaIndex(
    db: ref.watch(databaseProvider),
    scanner: ref.watch(mediaScannerProvider),
    prober: ref.watch(mediaProberProvider),
  );
  ref.onDispose(index.dispose);
  return index;
});

/// The library's videos or music, newest first.
final StreamProviderFamily<List<LibraryItem>, MediaKind> libraryItemsProvider =
    StreamProvider.family<List<LibraryItem>, MediaKind>(
      (ref, kind) => ref.watch(mediaIndexProvider).watch(kind),
    );

final mediaIndexStatusProvider = StreamProvider<MediaIndexStatus>(
  (ref) => ref.watch(mediaIndexProvider).statuses,
);
