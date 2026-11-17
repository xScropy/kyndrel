// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ResumePointsTable extends ResumePoints
    with TableInfo<$ResumePointsTable, ResumePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResumePointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    source,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resume_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResumePoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source};
  @override
  ResumePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResumePoint(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ResumePointsTable createAlias(String alias) {
    return $ResumePointsTable(attachedDatabase, alias);
  }
}

class ResumePoint extends DataClass implements Insertable<ResumePoint> {
  final String source;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  const ResumePoint({
    required this.source,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ResumePointsCompanion toCompanion(bool nullToAbsent) {
    return ResumePointsCompanion(
      source: Value(source),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory ResumePoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResumePoint(
      source: serializer.fromJson<String>(json['source']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ResumePoint copyWith({
    String? source,
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
  }) => ResumePoint(
    source: source ?? this.source,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ResumePoint copyWithCompanion(ResumePointsCompanion data) {
    return ResumePoint(
      source: data.source.present ? data.source.value : this.source,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResumePoint(')
          ..write('source: $source, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, positionMs, durationMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResumePoint &&
          other.source == this.source &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class ResumePointsCompanion extends UpdateCompanion<ResumePoint> {
  final Value<String> source;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ResumePointsCompanion({
    this.source = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResumePointsCompanion.insert({
    required String source,
    required int positionMs,
    required int durationMs,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       updatedAt = Value(updatedAt);
  static Insertable<ResumePoint> custom({
    Expression<String>? source,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResumePointsCompanion copyWith({
    Value<String>? source,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ResumePointsCompanion(
      source: source ?? this.source,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResumePointsCompanion(')
          ..write('source: $source, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KyndrelDatabase extends GeneratedDatabase {
  _$KyndrelDatabase(QueryExecutor e) : super(e);
  $KyndrelDatabaseManager get managers => $KyndrelDatabaseManager(this);
  late final $ResumePointsTable resumePoints = $ResumePointsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [resumePoints];
}

typedef $$ResumePointsTableCreateCompanionBuilder =
    ResumePointsCompanion Function({
      required String source,
      required int positionMs,
      required int durationMs,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ResumePointsTableUpdateCompanionBuilder =
    ResumePointsCompanion Function({
      Value<String> source,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ResumePointsTableFilterComposer
    extends Composer<_$KyndrelDatabase, $ResumePointsTable> {
  $$ResumePointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResumePointsTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $ResumePointsTable> {
  $$ResumePointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResumePointsTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $ResumePointsTable> {
  $$ResumePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ResumePointsTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $ResumePointsTable,
          ResumePoint,
          $$ResumePointsTableFilterComposer,
          $$ResumePointsTableOrderingComposer,
          $$ResumePointsTableAnnotationComposer,
          $$ResumePointsTableCreateCompanionBuilder,
          $$ResumePointsTableUpdateCompanionBuilder,
          (
            ResumePoint,
            BaseReferences<_$KyndrelDatabase, $ResumePointsTable, ResumePoint>,
          ),
          ResumePoint,
          PrefetchHooks Function()
        > {
  $$ResumePointsTableTableManager(
    _$KyndrelDatabase db,
    $ResumePointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResumePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResumePointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResumePointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResumePointsCompanion(
                source: source,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required int positionMs,
                required int durationMs,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ResumePointsCompanion.insert(
                source: source,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResumePointsTable, ResumePoint>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $ResumePointsTable,
                    ResumePoint
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResumePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $ResumePointsTable,
      ResumePoint,
      $$ResumePointsTableFilterComposer,
      $$ResumePointsTableOrderingComposer,
      $$ResumePointsTableAnnotationComposer,
      $$ResumePointsTableCreateCompanionBuilder,
      $$ResumePointsTableUpdateCompanionBuilder,
      (
        ResumePoint,
        BaseReferences<_$KyndrelDatabase, $ResumePointsTable, ResumePoint>,
      ),
      ResumePoint,
      PrefetchHooks Function()
    >;

class $KyndrelDatabaseManager {
  final _$KyndrelDatabase _db;
  $KyndrelDatabaseManager(this._db);
  $$ResumePointsTableTableManager get resumePoints =>
      $$ResumePointsTableTableManager(_db, _db.resumePoints);
}
