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

class $HistoryEntriesTable extends HistoryEntries
    with TableInfo<$HistoryEntriesTable, HistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta(
    'finished',
  );
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    source,
    title,
    positionMs,
    durationMs,
    lastPlayedAt,
    thumbnailPath,
    finished,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryEntry> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPlayedAtMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source};
  @override
  HistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryEntry(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}finished'],
      )!,
    );
  }

  @override
  $HistoryEntriesTable createAlias(String alias) {
    return $HistoryEntriesTable(attachedDatabase, alias);
  }
}

class HistoryEntry extends DataClass implements Insertable<HistoryEntry> {
  final String source;
  final String title;
  final int positionMs;
  final int durationMs;
  final DateTime lastPlayedAt;
  final String? thumbnailPath;
  final bool finished;
  const HistoryEntry({
    required this.source,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.lastPlayedAt,
    this.thumbnailPath,
    required this.finished,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['title'] = Variable<String>(title);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['finished'] = Variable<bool>(finished);
    return map;
  }

  HistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return HistoryEntriesCompanion(
      source: Value(source),
      title: Value(title),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      lastPlayedAt: Value(lastPlayedAt),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      finished: Value(finished),
    );
  }

  factory HistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEntry(
      source: serializer.fromJson<String>(json['source']),
      title: serializer.fromJson<String>(json['title']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      lastPlayedAt: serializer.fromJson<DateTime>(json['lastPlayedAt']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      finished: serializer.fromJson<bool>(json['finished']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'title': serializer.toJson<String>(title),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'lastPlayedAt': serializer.toJson<DateTime>(lastPlayedAt),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'finished': serializer.toJson<bool>(finished),
    };
  }

  HistoryEntry copyWith({
    String? source,
    String? title,
    int? positionMs,
    int? durationMs,
    DateTime? lastPlayedAt,
    Value<String?> thumbnailPath = const Value.absent(),
    bool? finished,
  }) => HistoryEntry(
    source: source ?? this.source,
    title: title ?? this.title,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    finished: finished ?? this.finished,
  );
  HistoryEntry copyWithCompanion(HistoryEntriesCompanion data) {
    return HistoryEntry(
      source: data.source.present ? data.source.value : this.source,
      title: data.title.present ? data.title.value : this.title,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      finished: data.finished.present ? data.finished.value : this.finished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntry(')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('finished: $finished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    source,
    title,
    positionMs,
    durationMs,
    lastPlayedAt,
    thumbnailPath,
    finished,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEntry &&
          other.source == this.source &&
          other.title == this.title &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.thumbnailPath == this.thumbnailPath &&
          other.finished == this.finished);
}

class HistoryEntriesCompanion extends UpdateCompanion<HistoryEntry> {
  final Value<String> source;
  final Value<String> title;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> lastPlayedAt;
  final Value<String?> thumbnailPath;
  final Value<bool> finished;
  final Value<int> rowid;
  const HistoryEntriesCompanion({
    this.source = const Value.absent(),
    this.title = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.finished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryEntriesCompanion.insert({
    required String source,
    required String title,
    required int positionMs,
    required int durationMs,
    required DateTime lastPlayedAt,
    this.thumbnailPath = const Value.absent(),
    this.finished = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       title = Value(title),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       lastPlayedAt = Value(lastPlayedAt);
  static Insertable<HistoryEntry> custom({
    Expression<String>? source,
    Expression<String>? title,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? lastPlayedAt,
    Expression<String>? thumbnailPath,
    Expression<bool>? finished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (title != null) 'title': title,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (finished != null) 'finished': finished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryEntriesCompanion copyWith({
    Value<String>? source,
    Value<String>? title,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? lastPlayedAt,
    Value<String?>? thumbnailPath,
    Value<bool>? finished,
    Value<int>? rowid,
  }) {
    return HistoryEntriesCompanion(
      source: source ?? this.source,
      title: title ?? this.title,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      finished: finished ?? this.finished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntriesCompanion(')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('finished: $finished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaMetadataTable extends MediaMetadata
    with TableInfo<$MediaMetadataTable, MediaMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manualMeta = const VerificationMeta('manual');
  @override
  late final GeneratedColumn<bool> manual = GeneratedColumn<bool>(
    'manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [source, json, manual, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaMetadataData> instance, {
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
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('manual')) {
      context.handle(
        _manualMeta,
        manual.isAcceptableOrUnknown(data['manual']!, _manualMeta),
      );
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
  MediaMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaMetadataData(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      manual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MediaMetadataTable createAlias(String alias) {
    return $MediaMetadataTable(attachedDatabase, alias);
  }
}

class MediaMetadataData extends DataClass
    implements Insertable<MediaMetadataData> {
  final String source;

  /// JSON of `MediaDetails`.
  final String json;

  /// True when the user picked or edited it; never overwritten by lookups.
  final bool manual;
  final DateTime updatedAt;
  const MediaMetadataData({
    required this.source,
    required this.json,
    required this.manual,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['json'] = Variable<String>(json);
    map['manual'] = Variable<bool>(manual);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaMetadataCompanion toCompanion(bool nullToAbsent) {
    return MediaMetadataCompanion(
      source: Value(source),
      json: Value(json),
      manual: Value(manual),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaMetadataData(
      source: serializer.fromJson<String>(json['source']),
      json: serializer.fromJson<String>(json['json']),
      manual: serializer.fromJson<bool>(json['manual']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'json': serializer.toJson<String>(json),
      'manual': serializer.toJson<bool>(manual),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaMetadataData copyWith({
    String? source,
    String? json,
    bool? manual,
    DateTime? updatedAt,
  }) => MediaMetadataData(
    source: source ?? this.source,
    json: json ?? this.json,
    manual: manual ?? this.manual,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MediaMetadataData copyWithCompanion(MediaMetadataCompanion data) {
    return MediaMetadataData(
      source: data.source.present ? data.source.value : this.source,
      json: data.json.present ? data.json.value : this.json,
      manual: data.manual.present ? data.manual.value : this.manual,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaMetadataData(')
          ..write('source: $source, ')
          ..write('json: $json, ')
          ..write('manual: $manual, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, json, manual, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaMetadataData &&
          other.source == this.source &&
          other.json == this.json &&
          other.manual == this.manual &&
          other.updatedAt == this.updatedAt);
}

class MediaMetadataCompanion extends UpdateCompanion<MediaMetadataData> {
  final Value<String> source;
  final Value<String> json;
  final Value<bool> manual;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MediaMetadataCompanion({
    this.source = const Value.absent(),
    this.json = const Value.absent(),
    this.manual = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaMetadataCompanion.insert({
    required String source,
    required String json,
    this.manual = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<MediaMetadataData> custom({
    Expression<String>? source,
    Expression<String>? json,
    Expression<bool>? manual,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (json != null) 'json': json,
      if (manual != null) 'manual': manual,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaMetadataCompanion copyWith({
    Value<String>? source,
    Value<String>? json,
    Value<bool>? manual,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MediaMetadataCompanion(
      source: source ?? this.source,
      json: json ?? this.json,
      manual: manual ?? this.manual,
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
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (manual.present) {
      map['manual'] = Variable<bool>(manual.value);
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
    return (StringBuffer('MediaMetadataCompanion(')
          ..write('source: $source, ')
          ..write('json: $json, ')
          ..write('manual: $manual, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryItemsTable extends LibraryItems
    with TableInfo<$LibraryItemsTable, LibraryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<DateTime> modified = GeneratedColumn<DateTime>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoCodecMeta = const VerificationMeta(
    'videoCodec',
  );
  @override
  late final GeneratedColumn<String> videoCodec = GeneratedColumn<String>(
    'video_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioCodecMeta = const VerificationMeta(
    'audioCodec',
  );
  @override
  late final GeneratedColumn<String> audioCodec = GeneratedColumn<String>(
    'audio_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNoMeta = const VerificationMeta(
    'trackNo',
  );
  @override
  late final GeneratedColumn<int> trackNo = GeneratedColumn<int>(
    'track_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _probedMeta = const VerificationMeta('probed');
  @override
  late final GeneratedColumn<bool> probed = GeneratedColumn<bool>(
    'probed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("probed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uri,
    name,
    folder,
    folderPath,
    kind,
    size,
    modified,
    added,
    durationMs,
    width,
    height,
    videoCodec,
    audioCodec,
    title,
    artist,
    album,
    trackNo,
    thumbnailPath,
    probed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMeta);
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('video_codec')) {
      context.handle(
        _videoCodecMeta,
        videoCodec.isAcceptableOrUnknown(data['video_codec']!, _videoCodecMeta),
      );
    }
    if (data.containsKey('audio_codec')) {
      context.handle(
        _audioCodecMeta,
        audioCodec.isAcceptableOrUnknown(data['audio_codec']!, _audioCodecMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('track_no')) {
      context.handle(
        _trackNoMeta,
        trackNo.isAcceptableOrUnknown(data['track_no']!, _trackNoMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('probed')) {
      context.handle(
        _probedMeta,
        probed.isAcceptableOrUnknown(data['probed']!, _probedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  LibraryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryItem(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified'],
      )!,
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      videoCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_codec'],
      ),
      audioCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_codec'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      trackNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_no'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      probed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}probed'],
      )!,
    );
  }

  @override
  $LibraryItemsTable createAlias(String alias) {
    return $LibraryItemsTable(attachedDatabase, alias);
  }
}

class LibraryItem extends DataClass implements Insertable<LibraryItem> {
  /// A file path, or a `content://` URI on Android.
  final String uri;
  final String name;

  /// Where it lives: [folderPath] groups, [folder] is shown.
  final String folder;
  final String folderPath;

  /// `video` or `audio`.
  final String kind;
  final int size;
  final DateTime modified;

  /// When Kyndrel first saw it (for "NEW").
  final DateTime added;
  final int? durationMs;
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? audioCodec;
  final String? title;
  final String? artist;
  final String? album;
  final int? trackNo;
  final String? thumbnailPath;

  /// Details and thumbnail have been read for this size and date.
  final bool probed;
  const LibraryItem({
    required this.uri,
    required this.name,
    required this.folder,
    required this.folderPath,
    required this.kind,
    required this.size,
    required this.modified,
    required this.added,
    this.durationMs,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.title,
    this.artist,
    this.album,
    this.trackNo,
    this.thumbnailPath,
    required this.probed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['name'] = Variable<String>(name);
    map['folder'] = Variable<String>(folder);
    map['folder_path'] = Variable<String>(folderPath);
    map['kind'] = Variable<String>(kind);
    map['size'] = Variable<int>(size);
    map['modified'] = Variable<DateTime>(modified);
    map['added'] = Variable<DateTime>(added);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || videoCodec != null) {
      map['video_codec'] = Variable<String>(videoCodec);
    }
    if (!nullToAbsent || audioCodec != null) {
      map['audio_codec'] = Variable<String>(audioCodec);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || trackNo != null) {
      map['track_no'] = Variable<int>(trackNo);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['probed'] = Variable<bool>(probed);
    return map;
  }

  LibraryItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryItemsCompanion(
      uri: Value(uri),
      name: Value(name),
      folder: Value(folder),
      folderPath: Value(folderPath),
      kind: Value(kind),
      size: Value(size),
      modified: Value(modified),
      added: Value(added),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      videoCodec: videoCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCodec),
      audioCodec: audioCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(audioCodec),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      trackNo: trackNo == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNo),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      probed: Value(probed),
    );
  }

  factory LibraryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryItem(
      uri: serializer.fromJson<String>(json['uri']),
      name: serializer.fromJson<String>(json['name']),
      folder: serializer.fromJson<String>(json['folder']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      kind: serializer.fromJson<String>(json['kind']),
      size: serializer.fromJson<int>(json['size']),
      modified: serializer.fromJson<DateTime>(json['modified']),
      added: serializer.fromJson<DateTime>(json['added']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      videoCodec: serializer.fromJson<String?>(json['videoCodec']),
      audioCodec: serializer.fromJson<String?>(json['audioCodec']),
      title: serializer.fromJson<String?>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      trackNo: serializer.fromJson<int?>(json['trackNo']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      probed: serializer.fromJson<bool>(json['probed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'name': serializer.toJson<String>(name),
      'folder': serializer.toJson<String>(folder),
      'folderPath': serializer.toJson<String>(folderPath),
      'kind': serializer.toJson<String>(kind),
      'size': serializer.toJson<int>(size),
      'modified': serializer.toJson<DateTime>(modified),
      'added': serializer.toJson<DateTime>(added),
      'durationMs': serializer.toJson<int?>(durationMs),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'videoCodec': serializer.toJson<String?>(videoCodec),
      'audioCodec': serializer.toJson<String?>(audioCodec),
      'title': serializer.toJson<String?>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'trackNo': serializer.toJson<int?>(trackNo),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'probed': serializer.toJson<bool>(probed),
    };
  }

  LibraryItem copyWith({
    String? uri,
    String? name,
    String? folder,
    String? folderPath,
    String? kind,
    int? size,
    DateTime? modified,
    DateTime? added,
    Value<int?> durationMs = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> videoCodec = const Value.absent(),
    Value<String?> audioCodec = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<int?> trackNo = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    bool? probed,
  }) => LibraryItem(
    uri: uri ?? this.uri,
    name: name ?? this.name,
    folder: folder ?? this.folder,
    folderPath: folderPath ?? this.folderPath,
    kind: kind ?? this.kind,
    size: size ?? this.size,
    modified: modified ?? this.modified,
    added: added ?? this.added,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    videoCodec: videoCodec.present ? videoCodec.value : this.videoCodec,
    audioCodec: audioCodec.present ? audioCodec.value : this.audioCodec,
    title: title.present ? title.value : this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    trackNo: trackNo.present ? trackNo.value : this.trackNo,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    probed: probed ?? this.probed,
  );
  LibraryItem copyWithCompanion(LibraryItemsCompanion data) {
    return LibraryItem(
      uri: data.uri.present ? data.uri.value : this.uri,
      name: data.name.present ? data.name.value : this.name,
      folder: data.folder.present ? data.folder.value : this.folder,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      kind: data.kind.present ? data.kind.value : this.kind,
      size: data.size.present ? data.size.value : this.size,
      modified: data.modified.present ? data.modified.value : this.modified,
      added: data.added.present ? data.added.value : this.added,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      videoCodec: data.videoCodec.present
          ? data.videoCodec.value
          : this.videoCodec,
      audioCodec: data.audioCodec.present
          ? data.audioCodec.value
          : this.audioCodec,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      trackNo: data.trackNo.present ? data.trackNo.value : this.trackNo,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      probed: data.probed.present ? data.probed.value : this.probed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItem(')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('folder: $folder, ')
          ..write('folderPath: $folderPath, ')
          ..write('kind: $kind, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('added: $added, ')
          ..write('durationMs: $durationMs, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('trackNo: $trackNo, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('probed: $probed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uri,
    name,
    folder,
    folderPath,
    kind,
    size,
    modified,
    added,
    durationMs,
    width,
    height,
    videoCodec,
    audioCodec,
    title,
    artist,
    album,
    trackNo,
    thumbnailPath,
    probed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItem &&
          other.uri == this.uri &&
          other.name == this.name &&
          other.folder == this.folder &&
          other.folderPath == this.folderPath &&
          other.kind == this.kind &&
          other.size == this.size &&
          other.modified == this.modified &&
          other.added == this.added &&
          other.durationMs == this.durationMs &&
          other.width == this.width &&
          other.height == this.height &&
          other.videoCodec == this.videoCodec &&
          other.audioCodec == this.audioCodec &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.trackNo == this.trackNo &&
          other.thumbnailPath == this.thumbnailPath &&
          other.probed == this.probed);
}

class LibraryItemsCompanion extends UpdateCompanion<LibraryItem> {
  final Value<String> uri;
  final Value<String> name;
  final Value<String> folder;
  final Value<String> folderPath;
  final Value<String> kind;
  final Value<int> size;
  final Value<DateTime> modified;
  final Value<DateTime> added;
  final Value<int?> durationMs;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> videoCodec;
  final Value<String?> audioCodec;
  final Value<String?> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<int?> trackNo;
  final Value<String?> thumbnailPath;
  final Value<bool> probed;
  final Value<int> rowid;
  const LibraryItemsCompanion({
    this.uri = const Value.absent(),
    this.name = const Value.absent(),
    this.folder = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.kind = const Value.absent(),
    this.size = const Value.absent(),
    this.modified = const Value.absent(),
    this.added = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.probed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryItemsCompanion.insert({
    required String uri,
    required String name,
    required String folder,
    required String folderPath,
    required String kind,
    this.size = const Value.absent(),
    required DateTime modified,
    required DateTime added,
    this.durationMs = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.probed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       name = Value(name),
       folder = Value(folder),
       folderPath = Value(folderPath),
       kind = Value(kind),
       modified = Value(modified),
       added = Value(added);
  static Insertable<LibraryItem> custom({
    Expression<String>? uri,
    Expression<String>? name,
    Expression<String>? folder,
    Expression<String>? folderPath,
    Expression<String>? kind,
    Expression<int>? size,
    Expression<DateTime>? modified,
    Expression<DateTime>? added,
    Expression<int>? durationMs,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? videoCodec,
    Expression<String>? audioCodec,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? trackNo,
    Expression<String>? thumbnailPath,
    Expression<bool>? probed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      if (folder != null) 'folder': folder,
      if (folderPath != null) 'folder_path': folderPath,
      if (kind != null) 'kind': kind,
      if (size != null) 'size': size,
      if (modified != null) 'modified': modified,
      if (added != null) 'added': added,
      if (durationMs != null) 'duration_ms': durationMs,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (videoCodec != null) 'video_codec': videoCodec,
      if (audioCodec != null) 'audio_codec': audioCodec,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (trackNo != null) 'track_no': trackNo,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (probed != null) 'probed': probed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryItemsCompanion copyWith({
    Value<String>? uri,
    Value<String>? name,
    Value<String>? folder,
    Value<String>? folderPath,
    Value<String>? kind,
    Value<int>? size,
    Value<DateTime>? modified,
    Value<DateTime>? added,
    Value<int?>? durationMs,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? videoCodec,
    Value<String?>? audioCodec,
    Value<String?>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<int?>? trackNo,
    Value<String?>? thumbnailPath,
    Value<bool>? probed,
    Value<int>? rowid,
  }) {
    return LibraryItemsCompanion(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      folder: folder ?? this.folder,
      folderPath: folderPath ?? this.folderPath,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      added: added ?? this.added,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      trackNo: trackNo ?? this.trackNo,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      probed: probed ?? this.probed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modified.present) {
      map['modified'] = Variable<DateTime>(modified.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (videoCodec.present) {
      map['video_codec'] = Variable<String>(videoCodec.value);
    }
    if (audioCodec.present) {
      map['audio_codec'] = Variable<String>(audioCodec.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (trackNo.present) {
      map['track_no'] = Variable<int>(trackNo.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (probed.present) {
      map['probed'] = Variable<bool>(probed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItemsCompanion(')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('folder: $folder, ')
          ..write('folderPath: $folderPath, ')
          ..write('kind: $kind, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('added: $added, ')
          ..write('durationMs: $durationMs, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('trackNo: $trackNo, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('probed: $probed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KyndrelDatabase extends GeneratedDatabase {
  _$KyndrelDatabase(QueryExecutor e) : super(e);
  $KyndrelDatabaseManager get managers => $KyndrelDatabaseManager(this);
  late final $ResumePointsTable resumePoints = $ResumePointsTable(this);
  late final $HistoryEntriesTable historyEntries = $HistoryEntriesTable(this);
  late final $MediaMetadataTable mediaMetadata = $MediaMetadataTable(this);
  late final $LibraryItemsTable libraryItems = $LibraryItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    resumePoints,
    historyEntries,
    mediaMetadata,
    libraryItems,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
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
typedef $$HistoryEntriesTableCreateCompanionBuilder =
    HistoryEntriesCompanion Function({
      required String source,
      required String title,
      required int positionMs,
      required int durationMs,
      required DateTime lastPlayedAt,
      Value<String?> thumbnailPath,
      Value<bool> finished,
      Value<int> rowid,
    });
typedef $$HistoryEntriesTableUpdateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<String> source,
      Value<String> title,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> lastPlayedAt,
      Value<String?> thumbnailPath,
      Value<bool> finished,
      Value<int> rowid,
    });

class $$HistoryEntriesTableFilterComposer
    extends Composer<_$KyndrelDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
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

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryEntriesTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
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

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryEntriesTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);
}

class $$HistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $HistoryEntriesTable,
          HistoryEntry,
          $$HistoryEntriesTableFilterComposer,
          $$HistoryEntriesTableOrderingComposer,
          $$HistoryEntriesTableAnnotationComposer,
          $$HistoryEntriesTableCreateCompanionBuilder,
          $$HistoryEntriesTableUpdateCompanionBuilder,
          (
            HistoryEntry,
            BaseReferences<
              _$KyndrelDatabase,
              $HistoryEntriesTable,
              HistoryEntry
            >,
          ),
          HistoryEntry,
          PrefetchHooks Function()
        > {
  $$HistoryEntriesTableTableManager(
    _$KyndrelDatabase db,
    $HistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> lastPlayedAt = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryEntriesCompanion(
                source: source,
                title: title,
                positionMs: positionMs,
                durationMs: durationMs,
                lastPlayedAt: lastPlayedAt,
                thumbnailPath: thumbnailPath,
                finished: finished,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required String title,
                required int positionMs,
                required int durationMs,
                required DateTime lastPlayedAt,
                Value<String?> thumbnailPath = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryEntriesCompanion.insert(
                source: source,
                title: title,
                positionMs: positionMs,
                durationMs: durationMs,
                lastPlayedAt: lastPlayedAt,
                thumbnailPath: thumbnailPath,
                finished: finished,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HistoryEntriesTable, HistoryEntry>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $HistoryEntriesTable,
                    HistoryEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $HistoryEntriesTable,
      HistoryEntry,
      $$HistoryEntriesTableFilterComposer,
      $$HistoryEntriesTableOrderingComposer,
      $$HistoryEntriesTableAnnotationComposer,
      $$HistoryEntriesTableCreateCompanionBuilder,
      $$HistoryEntriesTableUpdateCompanionBuilder,
      (
        HistoryEntry,
        BaseReferences<_$KyndrelDatabase, $HistoryEntriesTable, HistoryEntry>,
      ),
      HistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$MediaMetadataTableCreateCompanionBuilder =
    MediaMetadataCompanion Function({
      required String source,
      required String json,
      Value<bool> manual,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MediaMetadataTableUpdateCompanionBuilder =
    MediaMetadataCompanion Function({
      Value<String> source,
      Value<String> json,
      Value<bool> manual,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MediaMetadataTableFilterComposer
    extends Composer<_$KyndrelDatabase, $MediaMetadataTable> {
  $$MediaMetadataTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaMetadataTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $MediaMetadataTable> {
  $$MediaMetadataTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaMetadataTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $MediaMetadataTable> {
  $$MediaMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<bool> get manual =>
      $composableBuilder(column: $table.manual, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaMetadataTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $MediaMetadataTable,
          MediaMetadataData,
          $$MediaMetadataTableFilterComposer,
          $$MediaMetadataTableOrderingComposer,
          $$MediaMetadataTableAnnotationComposer,
          $$MediaMetadataTableCreateCompanionBuilder,
          $$MediaMetadataTableUpdateCompanionBuilder,
          (
            MediaMetadataData,
            BaseReferences<
              _$KyndrelDatabase,
              $MediaMetadataTable,
              MediaMetadataData
            >,
          ),
          MediaMetadataData,
          PrefetchHooks Function()
        > {
  $$MediaMetadataTableTableManager(
    _$KyndrelDatabase db,
    $MediaMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaMetadataCompanion(
                source: source,
                json: json,
                manual: manual,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required String json,
                Value<bool> manual = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaMetadataCompanion.insert(
                source: source,
                json: json,
                manual: manual,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaMetadataTable, MediaMetadataData>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $MediaMetadataTable,
                    MediaMetadataData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $MediaMetadataTable,
      MediaMetadataData,
      $$MediaMetadataTableFilterComposer,
      $$MediaMetadataTableOrderingComposer,
      $$MediaMetadataTableAnnotationComposer,
      $$MediaMetadataTableCreateCompanionBuilder,
      $$MediaMetadataTableUpdateCompanionBuilder,
      (
        MediaMetadataData,
        BaseReferences<
          _$KyndrelDatabase,
          $MediaMetadataTable,
          MediaMetadataData
        >,
      ),
      MediaMetadataData,
      PrefetchHooks Function()
    >;
typedef $$LibraryItemsTableCreateCompanionBuilder =
    LibraryItemsCompanion Function({
      required String uri,
      required String name,
      required String folder,
      required String folderPath,
      required String kind,
      Value<int> size,
      required DateTime modified,
      required DateTime added,
      Value<int?> durationMs,
      Value<int?> width,
      Value<int?> height,
      Value<String?> videoCodec,
      Value<String?> audioCodec,
      Value<String?> title,
      Value<String?> artist,
      Value<String?> album,
      Value<int?> trackNo,
      Value<String?> thumbnailPath,
      Value<bool> probed,
      Value<int> rowid,
    });
typedef $$LibraryItemsTableUpdateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<String> uri,
      Value<String> name,
      Value<String> folder,
      Value<String> folderPath,
      Value<String> kind,
      Value<int> size,
      Value<DateTime> modified,
      Value<DateTime> added,
      Value<int?> durationMs,
      Value<int?> width,
      Value<int?> height,
      Value<String?> videoCodec,
      Value<String?> audioCodec,
      Value<String?> title,
      Value<String?> artist,
      Value<String?> album,
      Value<int?> trackNo,
      Value<String?> thumbnailPath,
      Value<bool> probed,
      Value<int> rowid,
    });

class $$LibraryItemsTableFilterComposer
    extends Composer<_$KyndrelDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get probed => $composableBuilder(
    column: $table.probed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryItemsTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get probed => $composableBuilder(
    column: $table.probed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryItemsTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get trackNo =>
      $composableBuilder(column: $table.trackNo, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get probed =>
      $composableBuilder(column: $table.probed, builder: (column) => column);
}

class $$LibraryItemsTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $LibraryItemsTable,
          LibraryItem,
          $$LibraryItemsTableFilterComposer,
          $$LibraryItemsTableOrderingComposer,
          $$LibraryItemsTableAnnotationComposer,
          $$LibraryItemsTableCreateCompanionBuilder,
          $$LibraryItemsTableUpdateCompanionBuilder,
          (
            LibraryItem,
            BaseReferences<_$KyndrelDatabase, $LibraryItemsTable, LibraryItem>,
          ),
          LibraryItem,
          PrefetchHooks Function()
        > {
  $$LibraryItemsTableTableManager(
    _$KyndrelDatabase db,
    $LibraryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> modified = const Value.absent(),
                Value<DateTime> added = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<bool> probed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion(
                uri: uri,
                name: name,
                folder: folder,
                folderPath: folderPath,
                kind: kind,
                size: size,
                modified: modified,
                added: added,
                durationMs: durationMs,
                width: width,
                height: height,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                title: title,
                artist: artist,
                album: album,
                trackNo: trackNo,
                thumbnailPath: thumbnailPath,
                probed: probed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                required String name,
                required String folder,
                required String folderPath,
                required String kind,
                Value<int> size = const Value.absent(),
                required DateTime modified,
                required DateTime added,
                Value<int?> durationMs = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<bool> probed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion.insert(
                uri: uri,
                name: name,
                folder: folder,
                folderPath: folderPath,
                kind: kind,
                size: size,
                modified: modified,
                added: added,
                durationMs: durationMs,
                width: width,
                height: height,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                title: title,
                artist: artist,
                album: album,
                trackNo: trackNo,
                thumbnailPath: thumbnailPath,
                probed: probed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryItemsTable, LibraryItem>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $LibraryItemsTable,
                    LibraryItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $LibraryItemsTable,
      LibraryItem,
      $$LibraryItemsTableFilterComposer,
      $$LibraryItemsTableOrderingComposer,
      $$LibraryItemsTableAnnotationComposer,
      $$LibraryItemsTableCreateCompanionBuilder,
      $$LibraryItemsTableUpdateCompanionBuilder,
      (
        LibraryItem,
        BaseReferences<_$KyndrelDatabase, $LibraryItemsTable, LibraryItem>,
      ),
      LibraryItem,
      PrefetchHooks Function()
    >;

class $KyndrelDatabaseManager {
  final _$KyndrelDatabase _db;
  $KyndrelDatabaseManager(this._db);
  $$ResumePointsTableTableManager get resumePoints =>
      $$ResumePointsTableTableManager(_db, _db.resumePoints);
  $$HistoryEntriesTableTableManager get historyEntries =>
      $$HistoryEntriesTableTableManager(_db, _db.historyEntries);
  $$MediaMetadataTableTableManager get mediaMetadata =>
      $$MediaMetadataTableTableManager(_db, _db.mediaMetadata);
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db, _db.libraryItems);
}
