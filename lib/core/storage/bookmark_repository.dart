import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

/// Named moments in a file (task 8.8), like PotPlayer and MX Player.
class BookmarkRepository {
  new(this._db);

  final KyndrelDatabase _db;

  /// [source]'s bookmarks in time order.
  Stream<List<Bookmark>> watch(String source) =>
      (_db.select(_db.bookmarks)
            ..where((t) => t.source.equals(source))
            ..orderBy([(t) => OrderingTerm.asc(t.positionMs)]))
          .watch();

  Future<int> add(String source, Duration at, String label) => _db
      .into(_db.bookmarks)
      .insert(
        BookmarksCompanion.insert(
          source: source,
          positionMs: at.inMilliseconds,
          label: label,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> rename(int id, String label) =>
      (_db.update(_db.bookmarks)..where((t) => t.id.equals(id))).write(
        BookmarksCompanion(label: Value(label)),
      );

  Future<void> remove(int id) =>
      (_db.delete(_db.bookmarks)..where((t) => t.id.equals(id))).go();
}

final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (ref) => BookmarkRepository(ref.watch(databaseProvider)),
);

final StreamProviderFamily<List<Bookmark>, String> bookmarksProvider =
    StreamProvider.family<List<Bookmark>, String>(
      (ref, source) => ref.watch(bookmarkRepositoryProvider).watch(source),
    );
