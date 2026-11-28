import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

/// How often each part of a file was watched again (task 8.10), for the
/// "most replayed" shading over the seek bar. A file is cut into
/// [buckets] parts.
class ReplayRepository {
  new(this._db);

  final KyndrelDatabase _db;

  static const buckets = 100;

  static int bucketOf(double fraction) =>
      (fraction.clamp(0.0, 1.0) * buckets).floor().clamp(0, buckets - 1);

  /// One more replay of [from]…[to] (fractions of the file).
  Future<void> addRange(String source, double from, double to) =>
      _db.transaction(() async {
        final first = bucketOf(from);
        final last = bucketOf(to);
        for (var b = first; b <= last; b++) {
          await _db.customStatement(
            'INSERT INTO replays (source, bucket, count) VALUES (?, ?, 1) '
            'ON CONFLICT(source, bucket) DO UPDATE SET count = count + 1',
            [source, b],
          );
        }
        _db.notifyUpdates({TableUpdate.onTable(_db.replays)});
      });

  /// [source]'s counts, one per bucket.
  Stream<List<int>> watch(String source) =>
      (_db.select(
        _db.replays,
      )..where((t) => t.source.equals(source))).watch().map((rows) {
        final out = List<int>.filled(buckets, 0);
        for (final r in rows) {
          if (r.bucket >= 0 && r.bucket < buckets) out[r.bucket] = r.count;
        }
        return out;
      });

  Future<void> clear() => _db.delete(_db.replays).go();
}

final replayRepositoryProvider = Provider<ReplayRepository>(
  (ref) => ReplayRepository(ref.watch(databaseProvider)),
);

/// A source's replays as 0–1 heights (1 = the most replayed part); empty
/// before anything was replayed.
final StreamProviderFamily<List<double>, String> heatmapProvider =
    StreamProvider.family<List<double>, String>(
      (ref, source) =>
          ref.watch(replayRepositoryProvider).watch(source).map((c) {
            final most = c.fold(0, (m, v) => v > m ? v : m);
            return most == 0 ? const <double>[] : [for (final v in c) v / most];
          }),
    );
