import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Last known position per source (task 1.12).
class ResumePoints extends Table {
  TextColumn get source => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {source};
}

/// Everything that was played, newest first (task 3.3).
class HistoryEntries extends Table {
  TextColumn get source => text()();
  TextColumn get title => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get lastPlayedAt => dateTime()();
  TextColumn get thumbnailPath => text().nullable()();
  BoolColumn get finished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {source};
}

/// Cached and user-corrected metadata per source (task 3.4).
class MediaMetadata extends Table {
  TextColumn get source => text()();

  /// JSON of `MediaDetails`.
  TextColumn get json => text()();

  /// True when the user picked or edited it; never overwritten by lookups.
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {source};
}

@DriftDatabase(tables: [ResumePoints, HistoryEntries, MediaMetadata])
class KyndrelDatabase extends _$KyndrelDatabase {
  new([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'kyndrel',
              native: const DriftNativeOptions(
                // App support rather than Documents: always exists, and
                // keeps the database out of the user's files.
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(historyEntries);
        await m.createTable(mediaMetadata);
      }
    },
  );
}
