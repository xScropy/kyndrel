import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

/// Openings and credits (task 8.9). A row is keyed by a file's source
/// (found by comparing episodes) or by `show:<show>|<season>` (marked by
/// hand, at the same time in every episode).
class IntroRepository {
  new(this._db);

  final KyndrelDatabase _db;

  static String showKey(String show, int season) =>
      'show:${show.toLowerCase()}|$season';

  Future<IntroMark?> get(String key) => (_db.select(
    _db.introMarks,
  )..where((t) => t.show.equals(key))).getSingleOrNull();

  Future<void> save(
    String key, {
    Duration? introStart,
    Duration? introEnd,
    Duration? creditsFromEnd,
    bool manual = false,
  }) => _db
      .into(_db.introMarks)
      .insertOnConflictUpdate(
        IntroMarksCompanion.insert(
          show: key,
          introStartMs: Value(introStart?.inMilliseconds),
          introEndMs: Value(introEnd?.inMilliseconds),
          creditsFromEndMs: Value(creditsFromEnd?.inMilliseconds),
          manual: Value(manual),
        ),
      );
}

final introRepositoryProvider = Provider<IntroRepository>(
  (ref) => IntroRepository(ref.watch(databaseProvider)),
);
