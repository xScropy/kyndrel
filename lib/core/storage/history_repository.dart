import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

@immutable
class HistoryItem {
  const new({
    required this.source,
    required this.title,
    required this.position,
    required this.duration,
    required this.lastPlayedAt,
    this.thumbnailPath,
    this.finished = false,
  });

  final String source;
  final String title;
  final Duration position;
  final Duration duration;
  final DateTime lastPlayedAt;
  final String? thumbnailPath;
  final bool finished;

  /// 0–1, or null for unknown length.
  double? get progress => duration > Duration.zero
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : null;
}

/// Watch history and "continue watching" (task 3.3).
class HistoryRepository {
  new(this._db);

  final KyndrelDatabase _db;

  /// Records progress. Files watched to near the end are marked finished.
  Future<void> record({
    required String source,
    required String title,
    required Duration position,
    required Duration duration,
    String? thumbnailPath,
    bool? finished,
  }) async {
    final done =
        finished ??
        (duration > Duration.zero &&
            position >= duration - ResumeRepository.endMarginFor(duration));
    final existing = await _row(source);
    await _db
        .into(_db.historyEntries)
        .insertOnConflictUpdate(
          HistoryEntriesCompanion.insert(
            source: source,
            title: title,
            positionMs: position.inMilliseconds,
            durationMs: duration.inMilliseconds,
            lastPlayedAt: DateTime.now(),
            thumbnailPath: Value(thumbnailPath ?? existing?.thumbnailPath),
            finished: Value(done),
          ),
        );
  }

  Future<HistoryEntry?> _row(String source) => (_db.select(
    _db.historyEntries,
  )..where((r) => r.source.equals(source))).getSingleOrNull();

  /// Most recently played first.
  Stream<List<HistoryItem>> watchRecent({int limit = 50}) =>
      (_db.select(_db.historyEntries)
            ..orderBy([(r) => OrderingTerm.desc(r.lastPlayedAt)])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map(_toItem).toList());

  /// Started but not finished, most recent first.
  Stream<List<HistoryItem>> watchContinue({int limit = 12}) =>
      watchRecent(limit: 200).map(
        (items) => items
            .where(
              (i) =>
                  !i.finished &&
                  ResumeRepository.isResumable(i.position, i.duration),
            )
            .take(limit)
            .toList(),
      );

  Future<void> remove(String source) => (_db.delete(
    _db.historyEntries,
  )..where((r) => r.source.equals(source))).go();

  Future<void> clear() => _db.delete(_db.historyEntries).go();

  static HistoryItem _toItem(HistoryEntry r) => HistoryItem(
    source: r.source,
    title: r.title,
    position: Duration(milliseconds: r.positionMs),
    duration: Duration(milliseconds: r.durationMs),
    lastPlayedAt: r.lastPlayedAt,
    thumbnailPath: r.thumbnailPath,
    finished: r.finished,
  );
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);

final recentHistoryProvider = StreamProvider<List<HistoryItem>>(
  (ref) => ref.watch(historyRepositoryProvider).watchRecent(),
);

final continueWatchingProvider = StreamProvider<List<HistoryItem>>(
  (ref) => ref.watch(historyRepositoryProvider).watchContinue(),
);
