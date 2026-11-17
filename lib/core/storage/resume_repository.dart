import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/database.dart';

typedef ResumePoint = ({Duration position, Duration duration});

/// Stores where the user stopped watching each file (task 1.12).
class ResumeRepository {
  new(this._db);

  final KyndrelDatabase _db;

  /// Positions closer than this to the start aren't worth resuming.
  static const minPosition = Duration(seconds: 10);

  /// Positions this close to the end count as finished.
  static const endMargin = Duration(seconds: 30);

  /// Whether [position] in a file of [duration] is worth offering.
  static bool isResumable(Duration position, Duration duration) {
    if (position < minPosition) return false;
    if (duration <= Duration.zero) return true; // Live / unknown length.
    if (position > duration - endMargin) return false;
    return position < duration * 0.95;
  }

  /// Saves a resumable position, or forgets the file if it was finished or
  /// barely started.
  Future<void> save(String source, Duration position, Duration duration) {
    if (!isResumable(position, duration)) return remove(source);
    return _db
        .into(_db.resumePoints)
        .insertOnConflictUpdate(
          ResumePointsCompanion.insert(
            source: source,
            positionMs: position.inMilliseconds,
            durationMs: duration.inMilliseconds,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<ResumePoint?> get(String source) async {
    final row = await (_db.select(
      _db.resumePoints,
    )..where((r) => r.source.equals(source))).getSingleOrNull();
    if (row == null) return null;
    return (
      position: Duration(milliseconds: row.positionMs),
      duration: Duration(milliseconds: row.durationMs),
    );
  }

  Future<void> remove(String source) => (_db.delete(
    _db.resumePoints,
  )..where((r) => r.source.equals(source))).go();
}

final databaseProvider = Provider<KyndrelDatabase>((ref) {
  final db = KyndrelDatabase();
  ref.onDispose(db.close);
  return db;
});

final resumeRepositoryProvider = Provider<ResumeRepository>(
  (ref) => ResumeRepository(ref.watch(databaseProvider)),
);
