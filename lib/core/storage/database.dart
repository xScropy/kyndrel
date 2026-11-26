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

/// The videos and music found on the device (task 7.3).
class LibraryItems extends Table {
  /// A file path, or a `content://` URI on Android.
  TextColumn get uri => text()();
  TextColumn get name => text()();

  /// Where it lives: [folderPath] groups, [folder] is shown.
  TextColumn get folder => text()();
  TextColumn get folderPath => text()();

  /// `video` or `audio`.
  TextColumn get kind => text()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  DateTimeColumn get modified => dateTime()();

  /// When Kyndrel first saw it (for "NEW").
  DateTimeColumn get added => dateTime()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get videoCodec => text().nullable()();
  TextColumn get audioCodec => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get trackNo => integer().nullable()();
  TextColumn get thumbnailPath => text().nullable()();

  /// Details and thumbnail have been read for this size and date.
  BoolColumn get probed => boolean().withDefault(const Constant(false))();

  /// Marked as watched by hand, or played to the end (task 8.5).
  BoolColumn get watched => boolean().withDefault(const Constant(false))();

  /// A subtitle file with the same name sits next to it (task 8.5).
  BoolColumn get hasSubtitles => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}

/// The user's choices per library folder (task 8.5).
class LibraryFolders extends Table {
  TextColumn get path => text()();

  /// Left out of the library views (still scanned).
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Shown first.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// Shown only after unlocking; never in history.
  BoolColumn get private => boolean().withDefault(const Constant(false))();

  /// Remembered sort and layout of this folder; null uses the default.
  TextColumn get sort => text().nullable()();
  BoolColumn get descending => boolean().nullable()();
  TextColumn get layout => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Named moments in a file (task 8.8).
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  IntColumn get positionMs => integer()();
  TextColumn get label => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Playlists saved in the library (task 8.6).
class SavedPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class SavedPlaylistItems extends Table {
  IntColumn get playlistId => integer().references(SavedPlaylists, #id)();
  IntColumn get position => integer()();
  TextColumn get uri => text()();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, position};
}

/// Each file's own audio/subtitle track, speed, zoom and delays (8.8).
class FileSettings extends Table {
  TextColumn get source => text()();

  /// JSON of `PerFileSettings`.
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {source};
}

/// How often each part of a file was watched again (task 8.10): a seek
/// back counts for the part it lands in. [bucket] is a 1/100 of the file.
class Replays extends Table {
  TextColumn get source => text()();
  IntColumn get bucket => integer()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {source, bucket};
}

/// A show's opening and ending (task 8.9), found by comparing episodes or
/// marked by hand.
class IntroMarks extends Table {
  /// The show and season, e.g. `the expanse|1`.
  TextColumn get show => text()();
  IntColumn get introStartMs => integer().nullable()();
  IntColumn get introEndMs => integer().nullable()();

  /// Time from the end where the credits start.
  IntColumn get creditsFromEndMs => integer().nullable()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {show};
}

@DriftDatabase(
  tables: [
    ResumePoints,
    HistoryEntries,
    MediaMetadata,
    LibraryItems,
    LibraryFolders,
    Bookmarks,
    SavedPlaylists,
    SavedPlaylistItems,
    FileSettings,
    Replays,
    IntroMarks,
  ],
)
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(historyEntries);
        await m.createTable(mediaMetadata);
      }
      if (from < 3) await m.createTable(libraryItems);
      if (from < 4) {
        // Phase 8 (1.3): library choices, bookmarks, playlists, per-file
        // settings, replays and intros.
        if (from >= 3) {
          await m.addColumn(libraryItems, libraryItems.watched);
          await m.addColumn(libraryItems, libraryItems.hasSubtitles);
        }
        for (final t in <TableInfo<Table, Object?>>[
          libraryFolders,
          bookmarks,
          savedPlaylists,
          savedPlaylistItems,
          fileSettings,
          replays,
          introMarks,
        ]) {
          await m.createTable(t);
        }
      }
    },
  );
}
