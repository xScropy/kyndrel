import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:kyndrel/core/storage/database.dart';

/// In-memory database. Streams close synchronously so widget tests don't
/// hang on pending query timers.
KyndrelDatabase testDatabase() => KyndrelDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
