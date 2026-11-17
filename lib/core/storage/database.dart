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

@DriftDatabase(tables: [ResumePoints])
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
  int get schemaVersion => 1;
}
