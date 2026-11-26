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
  static const VerificationMeta _watchedMeta = const VerificationMeta(
    'watched',
  );
  @override
  late final GeneratedColumn<bool> watched = GeneratedColumn<bool>(
    'watched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("watched" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasSubtitlesMeta = const VerificationMeta(
    'hasSubtitles',
  );
  @override
  late final GeneratedColumn<bool> hasSubtitles = GeneratedColumn<bool>(
    'has_subtitles',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_subtitles" IN (0, 1))',
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
    watched,
    hasSubtitles,
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
    if (data.containsKey('watched')) {
      context.handle(
        _watchedMeta,
        watched.isAcceptableOrUnknown(data['watched']!, _watchedMeta),
      );
    }
    if (data.containsKey('has_subtitles')) {
      context.handle(
        _hasSubtitlesMeta,
        hasSubtitles.isAcceptableOrUnknown(
          data['has_subtitles']!,
          _hasSubtitlesMeta,
        ),
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
      watched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}watched'],
      )!,
      hasSubtitles: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_subtitles'],
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

  /// Marked as watched by hand, or played to the end (task 8.5).
  final bool watched;

  /// A subtitle file with the same name sits next to it (task 8.5).
  final bool hasSubtitles;
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
    required this.watched,
    required this.hasSubtitles,
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
    map['watched'] = Variable<bool>(watched);
    map['has_subtitles'] = Variable<bool>(hasSubtitles);
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
      watched: Value(watched),
      hasSubtitles: Value(hasSubtitles),
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
      watched: serializer.fromJson<bool>(json['watched']),
      hasSubtitles: serializer.fromJson<bool>(json['hasSubtitles']),
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
      'watched': serializer.toJson<bool>(watched),
      'hasSubtitles': serializer.toJson<bool>(hasSubtitles),
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
    bool? watched,
    bool? hasSubtitles,
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
    watched: watched ?? this.watched,
    hasSubtitles: hasSubtitles ?? this.hasSubtitles,
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
      watched: data.watched.present ? data.watched.value : this.watched,
      hasSubtitles: data.hasSubtitles.present
          ? data.hasSubtitles.value
          : this.hasSubtitles,
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
          ..write('probed: $probed, ')
          ..write('watched: $watched, ')
          ..write('hasSubtitles: $hasSubtitles')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    watched,
    hasSubtitles,
  ]);
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
          other.probed == this.probed &&
          other.watched == this.watched &&
          other.hasSubtitles == this.hasSubtitles);
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
  final Value<bool> watched;
  final Value<bool> hasSubtitles;
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
    this.watched = const Value.absent(),
    this.hasSubtitles = const Value.absent(),
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
    this.watched = const Value.absent(),
    this.hasSubtitles = const Value.absent(),
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
    Expression<bool>? watched,
    Expression<bool>? hasSubtitles,
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
      if (watched != null) 'watched': watched,
      if (hasSubtitles != null) 'has_subtitles': hasSubtitles,
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
    Value<bool>? watched,
    Value<bool>? hasSubtitles,
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
      watched: watched ?? this.watched,
      hasSubtitles: hasSubtitles ?? this.hasSubtitles,
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
    if (watched.present) {
      map['watched'] = Variable<bool>(watched.value);
    }
    if (hasSubtitles.present) {
      map['has_subtitles'] = Variable<bool>(hasSubtitles.value);
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
          ..write('watched: $watched, ')
          ..write('hasSubtitles: $hasSubtitles, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _privateMeta = const VerificationMeta(
    'private',
  );
  @override
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
    'private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descendingMeta = const VerificationMeta(
    'descending',
  );
  @override
  late final GeneratedColumn<bool> descending = GeneratedColumn<bool>(
    'descending',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("descending" IN (0, 1))',
    ),
  );
  static const VerificationMeta _layoutMeta = const VerificationMeta('layout');
  @override
  late final GeneratedColumn<String> layout = GeneratedColumn<String>(
    'layout',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    hidden,
    pinned,
    private,
    sort,
    descending,
    layout,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('private')) {
      context.handle(
        _privateMeta,
        private.isAcceptableOrUnknown(data['private']!, _privateMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('descending')) {
      context.handle(
        _descendingMeta,
        descending.isAcceptableOrUnknown(data['descending']!, _descendingMeta),
      );
    }
    if (data.containsKey('layout')) {
      context.handle(
        _layoutMeta,
        layout.isAcceptableOrUnknown(data['layout']!, _layoutMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LibraryFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolder(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      private: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}private'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      ),
      descending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}descending'],
      ),
      layout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout'],
      ),
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolder extends DataClass implements Insertable<LibraryFolder> {
  final String path;

  /// Left out of the library views (still scanned).
  final bool hidden;

  /// Shown first.
  final bool pinned;

  /// Shown only after unlocking; never in history.
  final bool private;

  /// Remembered sort and layout of this folder; null uses the default.
  final String? sort;
  final bool? descending;
  final String? layout;
  const LibraryFolder({
    required this.path,
    required this.hidden,
    required this.pinned,
    required this.private,
    this.sort,
    this.descending,
    this.layout,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['hidden'] = Variable<bool>(hidden);
    map['pinned'] = Variable<bool>(pinned);
    map['private'] = Variable<bool>(private);
    if (!nullToAbsent || sort != null) {
      map['sort'] = Variable<String>(sort);
    }
    if (!nullToAbsent || descending != null) {
      map['descending'] = Variable<bool>(descending);
    }
    if (!nullToAbsent || layout != null) {
      map['layout'] = Variable<String>(layout);
    }
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      path: Value(path),
      hidden: Value(hidden),
      pinned: Value(pinned),
      private: Value(private),
      sort: sort == null && nullToAbsent ? const Value.absent() : Value(sort),
      descending: descending == null && nullToAbsent
          ? const Value.absent()
          : Value(descending),
      layout: layout == null && nullToAbsent
          ? const Value.absent()
          : Value(layout),
    );
  }

  factory LibraryFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolder(
      path: serializer.fromJson<String>(json['path']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      private: serializer.fromJson<bool>(json['private']),
      sort: serializer.fromJson<String?>(json['sort']),
      descending: serializer.fromJson<bool?>(json['descending']),
      layout: serializer.fromJson<String?>(json['layout']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'hidden': serializer.toJson<bool>(hidden),
      'pinned': serializer.toJson<bool>(pinned),
      'private': serializer.toJson<bool>(private),
      'sort': serializer.toJson<String?>(sort),
      'descending': serializer.toJson<bool?>(descending),
      'layout': serializer.toJson<String?>(layout),
    };
  }

  LibraryFolder copyWith({
    String? path,
    bool? hidden,
    bool? pinned,
    bool? private,
    Value<String?> sort = const Value.absent(),
    Value<bool?> descending = const Value.absent(),
    Value<String?> layout = const Value.absent(),
  }) => LibraryFolder(
    path: path ?? this.path,
    hidden: hidden ?? this.hidden,
    pinned: pinned ?? this.pinned,
    private: private ?? this.private,
    sort: sort.present ? sort.value : this.sort,
    descending: descending.present ? descending.value : this.descending,
    layout: layout.present ? layout.value : this.layout,
  );
  LibraryFolder copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolder(
      path: data.path.present ? data.path.value : this.path,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      private: data.private.present ? data.private.value : this.private,
      sort: data.sort.present ? data.sort.value : this.sort,
      descending: data.descending.present
          ? data.descending.value
          : this.descending,
      layout: data.layout.present ? data.layout.value : this.layout,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolder(')
          ..write('path: $path, ')
          ..write('hidden: $hidden, ')
          ..write('pinned: $pinned, ')
          ..write('private: $private, ')
          ..write('sort: $sort, ')
          ..write('descending: $descending, ')
          ..write('layout: $layout')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(path, hidden, pinned, private, sort, descending, layout);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolder &&
          other.path == this.path &&
          other.hidden == this.hidden &&
          other.pinned == this.pinned &&
          other.private == this.private &&
          other.sort == this.sort &&
          other.descending == this.descending &&
          other.layout == this.layout);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolder> {
  final Value<String> path;
  final Value<bool> hidden;
  final Value<bool> pinned;
  final Value<bool> private;
  final Value<String?> sort;
  final Value<bool?> descending;
  final Value<String?> layout;
  final Value<int> rowid;
  const LibraryFoldersCompanion({
    this.path = const Value.absent(),
    this.hidden = const Value.absent(),
    this.pinned = const Value.absent(),
    this.private = const Value.absent(),
    this.sort = const Value.absent(),
    this.descending = const Value.absent(),
    this.layout = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    required String path,
    this.hidden = const Value.absent(),
    this.pinned = const Value.absent(),
    this.private = const Value.absent(),
    this.sort = const Value.absent(),
    this.descending = const Value.absent(),
    this.layout = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path);
  static Insertable<LibraryFolder> custom({
    Expression<String>? path,
    Expression<bool>? hidden,
    Expression<bool>? pinned,
    Expression<bool>? private,
    Expression<String>? sort,
    Expression<bool>? descending,
    Expression<String>? layout,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (hidden != null) 'hidden': hidden,
      if (pinned != null) 'pinned': pinned,
      if (private != null) 'private': private,
      if (sort != null) 'sort': sort,
      if (descending != null) 'descending': descending,
      if (layout != null) 'layout': layout,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<String>? path,
    Value<bool>? hidden,
    Value<bool>? pinned,
    Value<bool>? private,
    Value<String?>? sort,
    Value<bool?>? descending,
    Value<String?>? layout,
    Value<int>? rowid,
  }) {
    return LibraryFoldersCompanion(
      path: path ?? this.path,
      hidden: hidden ?? this.hidden,
      pinned: pinned ?? this.pinned,
      private: private ?? this.private,
      sort: sort ?? this.sort,
      descending: descending ?? this.descending,
      layout: layout ?? this.layout,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (descending.present) {
      map['descending'] = Variable<bool>(descending.value);
    }
    if (layout.present) {
      map['layout'] = Variable<String>(layout.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('path: $path, ')
          ..write('hidden: $hidden, ')
          ..write('pinned: $pinned, ')
          ..write('private: $private, ')
          ..write('sort: $sort, ')
          ..write('descending: $descending, ')
          ..write('layout: $layout, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
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
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    positionMs,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
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
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;
  final String source;
  final int positionMs;
  final String label;
  final DateTime createdAt;
  const Bookmark({
    required this.id,
    required this.source,
    required this.positionMs,
    required this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['position_ms'] = Variable<int>(positionMs);
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      source: Value(source),
      positionMs: Value(positionMs),
      label: Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'positionMs': serializer.toJson<int>(positionMs),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({
    int? id,
    String? source,
    int? positionMs,
    String? label,
    DateTime? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    source: source ?? this.source,
    positionMs: positionMs ?? this.positionMs,
    label: label ?? this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('positionMs: $positionMs, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, positionMs, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.source == this.source &&
          other.positionMs == this.positionMs &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> source;
  final Value<int> positionMs;
  final Value<String> label;
  final Value<DateTime> createdAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required int positionMs,
    required String label,
    required DateTime createdAt,
  }) : source = Value(source),
       positionMs = Value(positionMs),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<int>? positionMs,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (positionMs != null) 'position_ms': positionMs,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<int>? positionMs,
    Value<String>? label,
    Value<DateTime>? createdAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      positionMs: positionMs ?? this.positionMs,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('positionMs: $positionMs, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SavedPlaylistsTable extends SavedPlaylists
    with TableInfo<$SavedPlaylistsTable, SavedPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPlaylist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SavedPlaylistsTable createAlias(String alias) {
    return $SavedPlaylistsTable(attachedDatabase, alias);
  }
}

class SavedPlaylist extends DataClass implements Insertable<SavedPlaylist> {
  final int id;
  final String name;
  final DateTime createdAt;
  const SavedPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavedPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return SavedPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory SavedPlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPlaylist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavedPlaylist copyWith({int? id, String? name, DateTime? createdAt}) =>
      SavedPlaylist(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  SavedPlaylist copyWithCompanion(SavedPlaylistsCompanion data) {
    return SavedPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class SavedPlaylistsCompanion extends UpdateCompanion<SavedPlaylist> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const SavedPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SavedPlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SavedPlaylist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SavedPlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return SavedPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SavedPlaylistItemsTable extends SavedPlaylistItems
    with TableInfo<$SavedPlaylistItemsTable, SavedPlaylistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_playlists (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, position, uri];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPlaylistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, position};
  @override
  SavedPlaylistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPlaylistItem(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
    );
  }

  @override
  $SavedPlaylistItemsTable createAlias(String alias) {
    return $SavedPlaylistItemsTable(attachedDatabase, alias);
  }
}

class SavedPlaylistItem extends DataClass
    implements Insertable<SavedPlaylistItem> {
  final int playlistId;
  final int position;
  final String uri;
  const SavedPlaylistItem({
    required this.playlistId,
    required this.position,
    required this.uri,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['position'] = Variable<int>(position);
    map['uri'] = Variable<String>(uri);
    return map;
  }

  SavedPlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return SavedPlaylistItemsCompanion(
      playlistId: Value(playlistId),
      position: Value(position),
      uri: Value(uri),
    );
  }

  factory SavedPlaylistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPlaylistItem(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      position: serializer.fromJson<int>(json['position']),
      uri: serializer.fromJson<String>(json['uri']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'position': serializer.toJson<int>(position),
      'uri': serializer.toJson<String>(uri),
    };
  }

  SavedPlaylistItem copyWith({int? playlistId, int? position, String? uri}) =>
      SavedPlaylistItem(
        playlistId: playlistId ?? this.playlistId,
        position: position ?? this.position,
        uri: uri ?? this.uri,
      );
  SavedPlaylistItem copyWithCompanion(SavedPlaylistItemsCompanion data) {
    return SavedPlaylistItem(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      position: data.position.present ? data.position.value : this.position,
      uri: data.uri.present ? data.uri.value : this.uri,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlaylistItem(')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('uri: $uri')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, position, uri);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPlaylistItem &&
          other.playlistId == this.playlistId &&
          other.position == this.position &&
          other.uri == this.uri);
}

class SavedPlaylistItemsCompanion extends UpdateCompanion<SavedPlaylistItem> {
  final Value<int> playlistId;
  final Value<int> position;
  final Value<String> uri;
  final Value<int> rowid;
  const SavedPlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.position = const Value.absent(),
    this.uri = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedPlaylistItemsCompanion.insert({
    required int playlistId,
    required int position,
    required String uri,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       position = Value(position),
       uri = Value(uri);
  static Insertable<SavedPlaylistItem> custom({
    Expression<int>? playlistId,
    Expression<int>? position,
    Expression<String>? uri,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (position != null) 'position': position,
      if (uri != null) 'uri': uri,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedPlaylistItemsCompanion copyWith({
    Value<int>? playlistId,
    Value<int>? position,
    Value<String>? uri,
    Value<int>? rowid,
  }) {
    return SavedPlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      position: position ?? this.position,
      uri: uri ?? this.uri,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('uri: $uri, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileSettingsTable extends FileSettings
    with TableInfo<$FileSettingsTable, FileSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileSettingsTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [source, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileSetting> instance, {
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
  FileSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileSetting(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FileSettingsTable createAlias(String alias) {
    return $FileSettingsTable(attachedDatabase, alias);
  }
}

class FileSetting extends DataClass implements Insertable<FileSetting> {
  final String source;

  /// JSON of `PerFileSettings`.
  final String json;
  final DateTime updatedAt;
  const FileSetting({
    required this.source,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FileSettingsCompanion toCompanion(bool nullToAbsent) {
    return FileSettingsCompanion(
      source: Value(source),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileSetting(
      source: serializer.fromJson<String>(json['source']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FileSetting copyWith({String? source, String? json, DateTime? updatedAt}) =>
      FileSetting(
        source: source ?? this.source,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FileSetting copyWithCompanion(FileSettingsCompanion data) {
    return FileSetting(
      source: data.source.present ? data.source.value : this.source,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileSetting(')
          ..write('source: $source, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileSetting &&
          other.source == this.source &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class FileSettingsCompanion extends UpdateCompanion<FileSetting> {
  final Value<String> source;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FileSettingsCompanion({
    this.source = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileSettingsCompanion.insert({
    required String source,
    required String json,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<FileSetting> custom({
    Expression<String>? source,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileSettingsCompanion copyWith({
    Value<String>? source,
    Value<String>? json,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FileSettingsCompanion(
      source: source ?? this.source,
      json: json ?? this.json,
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
    return (StringBuffer('FileSettingsCompanion(')
          ..write('source: $source, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReplaysTable extends Replays with TableInfo<$ReplaysTable, Replay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReplaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<int> bucket = GeneratedColumn<int>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [source, bucket, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'replays';
  @override
  VerificationContext validateIntegrity(
    Insertable<Replay> instance, {
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
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source, bucket};
  @override
  Replay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Replay(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $ReplaysTable createAlias(String alias) {
    return $ReplaysTable(attachedDatabase, alias);
  }
}

class Replay extends DataClass implements Insertable<Replay> {
  final String source;
  final int bucket;
  final int count;
  const Replay({
    required this.source,
    required this.bucket,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['bucket'] = Variable<int>(bucket);
    map['count'] = Variable<int>(count);
    return map;
  }

  ReplaysCompanion toCompanion(bool nullToAbsent) {
    return ReplaysCompanion(
      source: Value(source),
      bucket: Value(bucket),
      count: Value(count),
    );
  }

  factory Replay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Replay(
      source: serializer.fromJson<String>(json['source']),
      bucket: serializer.fromJson<int>(json['bucket']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'bucket': serializer.toJson<int>(bucket),
      'count': serializer.toJson<int>(count),
    };
  }

  Replay copyWith({String? source, int? bucket, int? count}) => Replay(
    source: source ?? this.source,
    bucket: bucket ?? this.bucket,
    count: count ?? this.count,
  );
  Replay copyWithCompanion(ReplaysCompanion data) {
    return Replay(
      source: data.source.present ? data.source.value : this.source,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Replay(')
          ..write('source: $source, ')
          ..write('bucket: $bucket, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, bucket, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Replay &&
          other.source == this.source &&
          other.bucket == this.bucket &&
          other.count == this.count);
}

class ReplaysCompanion extends UpdateCompanion<Replay> {
  final Value<String> source;
  final Value<int> bucket;
  final Value<int> count;
  final Value<int> rowid;
  const ReplaysCompanion({
    this.source = const Value.absent(),
    this.bucket = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReplaysCompanion.insert({
    required String source,
    required int bucket,
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       bucket = Value(bucket);
  static Insertable<Replay> custom({
    Expression<String>? source,
    Expression<int>? bucket,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (bucket != null) 'bucket': bucket,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReplaysCompanion copyWith({
    Value<String>? source,
    Value<int>? bucket,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return ReplaysCompanion(
      source: source ?? this.source,
      bucket: bucket ?? this.bucket,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<int>(bucket.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReplaysCompanion(')
          ..write('source: $source, ')
          ..write('bucket: $bucket, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntroMarksTable extends IntroMarks
    with TableInfo<$IntroMarksTable, IntroMark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntroMarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _showMeta = const VerificationMeta('show');
  @override
  late final GeneratedColumn<String> show = GeneratedColumn<String>(
    'show',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _introStartMsMeta = const VerificationMeta(
    'introStartMs',
  );
  @override
  late final GeneratedColumn<int> introStartMs = GeneratedColumn<int>(
    'intro_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introEndMsMeta = const VerificationMeta(
    'introEndMs',
  );
  @override
  late final GeneratedColumn<int> introEndMs = GeneratedColumn<int>(
    'intro_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditsFromEndMsMeta = const VerificationMeta(
    'creditsFromEndMs',
  );
  @override
  late final GeneratedColumn<int> creditsFromEndMs = GeneratedColumn<int>(
    'credits_from_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    show,
    introStartMs,
    introEndMs,
    creditsFromEndMs,
    manual,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intro_marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntroMark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('show')) {
      context.handle(
        _showMeta,
        show.isAcceptableOrUnknown(data['show']!, _showMeta),
      );
    } else if (isInserting) {
      context.missing(_showMeta);
    }
    if (data.containsKey('intro_start_ms')) {
      context.handle(
        _introStartMsMeta,
        introStartMs.isAcceptableOrUnknown(
          data['intro_start_ms']!,
          _introStartMsMeta,
        ),
      );
    }
    if (data.containsKey('intro_end_ms')) {
      context.handle(
        _introEndMsMeta,
        introEndMs.isAcceptableOrUnknown(
          data['intro_end_ms']!,
          _introEndMsMeta,
        ),
      );
    }
    if (data.containsKey('credits_from_end_ms')) {
      context.handle(
        _creditsFromEndMsMeta,
        creditsFromEndMs.isAcceptableOrUnknown(
          data['credits_from_end_ms']!,
          _creditsFromEndMsMeta,
        ),
      );
    }
    if (data.containsKey('manual')) {
      context.handle(
        _manualMeta,
        manual.isAcceptableOrUnknown(data['manual']!, _manualMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {show};
  @override
  IntroMark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntroMark(
      show: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show'],
      )!,
      introStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intro_start_ms'],
      ),
      introEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intro_end_ms'],
      ),
      creditsFromEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credits_from_end_ms'],
      ),
      manual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual'],
      )!,
    );
  }

  @override
  $IntroMarksTable createAlias(String alias) {
    return $IntroMarksTable(attachedDatabase, alias);
  }
}

class IntroMark extends DataClass implements Insertable<IntroMark> {
  /// The show and season, e.g. `the expanse|1`.
  final String show;
  final int? introStartMs;
  final int? introEndMs;

  /// Time from the end where the credits start.
  final int? creditsFromEndMs;
  final bool manual;
  const IntroMark({
    required this.show,
    this.introStartMs,
    this.introEndMs,
    this.creditsFromEndMs,
    required this.manual,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['show'] = Variable<String>(show);
    if (!nullToAbsent || introStartMs != null) {
      map['intro_start_ms'] = Variable<int>(introStartMs);
    }
    if (!nullToAbsent || introEndMs != null) {
      map['intro_end_ms'] = Variable<int>(introEndMs);
    }
    if (!nullToAbsent || creditsFromEndMs != null) {
      map['credits_from_end_ms'] = Variable<int>(creditsFromEndMs);
    }
    map['manual'] = Variable<bool>(manual);
    return map;
  }

  IntroMarksCompanion toCompanion(bool nullToAbsent) {
    return IntroMarksCompanion(
      show: Value(show),
      introStartMs: introStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(introStartMs),
      introEndMs: introEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(introEndMs),
      creditsFromEndMs: creditsFromEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(creditsFromEndMs),
      manual: Value(manual),
    );
  }

  factory IntroMark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntroMark(
      show: serializer.fromJson<String>(json['show']),
      introStartMs: serializer.fromJson<int?>(json['introStartMs']),
      introEndMs: serializer.fromJson<int?>(json['introEndMs']),
      creditsFromEndMs: serializer.fromJson<int?>(json['creditsFromEndMs']),
      manual: serializer.fromJson<bool>(json['manual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'show': serializer.toJson<String>(show),
      'introStartMs': serializer.toJson<int?>(introStartMs),
      'introEndMs': serializer.toJson<int?>(introEndMs),
      'creditsFromEndMs': serializer.toJson<int?>(creditsFromEndMs),
      'manual': serializer.toJson<bool>(manual),
    };
  }

  IntroMark copyWith({
    String? show,
    Value<int?> introStartMs = const Value.absent(),
    Value<int?> introEndMs = const Value.absent(),
    Value<int?> creditsFromEndMs = const Value.absent(),
    bool? manual,
  }) => IntroMark(
    show: show ?? this.show,
    introStartMs: introStartMs.present ? introStartMs.value : this.introStartMs,
    introEndMs: introEndMs.present ? introEndMs.value : this.introEndMs,
    creditsFromEndMs: creditsFromEndMs.present
        ? creditsFromEndMs.value
        : this.creditsFromEndMs,
    manual: manual ?? this.manual,
  );
  IntroMark copyWithCompanion(IntroMarksCompanion data) {
    return IntroMark(
      show: data.show.present ? data.show.value : this.show,
      introStartMs: data.introStartMs.present
          ? data.introStartMs.value
          : this.introStartMs,
      introEndMs: data.introEndMs.present
          ? data.introEndMs.value
          : this.introEndMs,
      creditsFromEndMs: data.creditsFromEndMs.present
          ? data.creditsFromEndMs.value
          : this.creditsFromEndMs,
      manual: data.manual.present ? data.manual.value : this.manual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntroMark(')
          ..write('show: $show, ')
          ..write('introStartMs: $introStartMs, ')
          ..write('introEndMs: $introEndMs, ')
          ..write('creditsFromEndMs: $creditsFromEndMs, ')
          ..write('manual: $manual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(show, introStartMs, introEndMs, creditsFromEndMs, manual);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntroMark &&
          other.show == this.show &&
          other.introStartMs == this.introStartMs &&
          other.introEndMs == this.introEndMs &&
          other.creditsFromEndMs == this.creditsFromEndMs &&
          other.manual == this.manual);
}

class IntroMarksCompanion extends UpdateCompanion<IntroMark> {
  final Value<String> show;
  final Value<int?> introStartMs;
  final Value<int?> introEndMs;
  final Value<int?> creditsFromEndMs;
  final Value<bool> manual;
  final Value<int> rowid;
  const IntroMarksCompanion({
    this.show = const Value.absent(),
    this.introStartMs = const Value.absent(),
    this.introEndMs = const Value.absent(),
    this.creditsFromEndMs = const Value.absent(),
    this.manual = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntroMarksCompanion.insert({
    required String show,
    this.introStartMs = const Value.absent(),
    this.introEndMs = const Value.absent(),
    this.creditsFromEndMs = const Value.absent(),
    this.manual = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : show = Value(show);
  static Insertable<IntroMark> custom({
    Expression<String>? show,
    Expression<int>? introStartMs,
    Expression<int>? introEndMs,
    Expression<int>? creditsFromEndMs,
    Expression<bool>? manual,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (show != null) 'show': show,
      if (introStartMs != null) 'intro_start_ms': introStartMs,
      if (introEndMs != null) 'intro_end_ms': introEndMs,
      if (creditsFromEndMs != null) 'credits_from_end_ms': creditsFromEndMs,
      if (manual != null) 'manual': manual,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntroMarksCompanion copyWith({
    Value<String>? show,
    Value<int?>? introStartMs,
    Value<int?>? introEndMs,
    Value<int?>? creditsFromEndMs,
    Value<bool>? manual,
    Value<int>? rowid,
  }) {
    return IntroMarksCompanion(
      show: show ?? this.show,
      introStartMs: introStartMs ?? this.introStartMs,
      introEndMs: introEndMs ?? this.introEndMs,
      creditsFromEndMs: creditsFromEndMs ?? this.creditsFromEndMs,
      manual: manual ?? this.manual,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (show.present) {
      map['show'] = Variable<String>(show.value);
    }
    if (introStartMs.present) {
      map['intro_start_ms'] = Variable<int>(introStartMs.value);
    }
    if (introEndMs.present) {
      map['intro_end_ms'] = Variable<int>(introEndMs.value);
    }
    if (creditsFromEndMs.present) {
      map['credits_from_end_ms'] = Variable<int>(creditsFromEndMs.value);
    }
    if (manual.present) {
      map['manual'] = Variable<bool>(manual.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntroMarksCompanion(')
          ..write('show: $show, ')
          ..write('introStartMs: $introStartMs, ')
          ..write('introEndMs: $introEndMs, ')
          ..write('creditsFromEndMs: $creditsFromEndMs, ')
          ..write('manual: $manual, ')
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
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $SavedPlaylistsTable savedPlaylists = $SavedPlaylistsTable(this);
  late final $SavedPlaylistItemsTable savedPlaylistItems =
      $SavedPlaylistItemsTable(this);
  late final $FileSettingsTable fileSettings = $FileSettingsTable(this);
  late final $ReplaysTable replays = $ReplaysTable(this);
  late final $IntroMarksTable introMarks = $IntroMarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    resumePoints,
    historyEntries,
    mediaMetadata,
    libraryItems,
    libraryFolders,
    bookmarks,
    savedPlaylists,
    savedPlaylistItems,
    fileSettings,
    replays,
    introMarks,
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
      Value<bool> watched,
      Value<bool> hasSubtitles,
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
      Value<bool> watched,
      Value<bool> hasSubtitles,
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

  ColumnFilters<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSubtitles => $composableBuilder(
    column: $table.hasSubtitles,
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

  ColumnOrderings<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSubtitles => $composableBuilder(
    column: $table.hasSubtitles,
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

  GeneratedColumn<bool> get watched =>
      $composableBuilder(column: $table.watched, builder: (column) => column);

  GeneratedColumn<bool> get hasSubtitles => $composableBuilder(
    column: $table.hasSubtitles,
    builder: (column) => column,
  );
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
                Value<bool> watched = const Value.absent(),
                Value<bool> hasSubtitles = const Value.absent(),
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
                watched: watched,
                hasSubtitles: hasSubtitles,
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
                Value<bool> watched = const Value.absent(),
                Value<bool> hasSubtitles = const Value.absent(),
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
                watched: watched,
                hasSubtitles: hasSubtitles,
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
typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      required String path,
      Value<bool> hidden,
      Value<bool> pinned,
      Value<bool> private,
      Value<String?> sort,
      Value<bool?> descending,
      Value<String?> layout,
      Value<int> rowid,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<String> path,
      Value<bool> hidden,
      Value<bool> pinned,
      Value<bool> private,
      Value<String?> sort,
      Value<bool?> descending,
      Value<String?> layout,
      Value<int> rowid,
    });

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$KyndrelDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get descending => $composableBuilder(
    column: $table.descending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get descending => $composableBuilder(
    column: $table.descending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<bool> get descending => $composableBuilder(
    column: $table.descending,
    builder: (column) => column,
  );

  GeneratedColumn<String> get layout =>
      $composableBuilder(column: $table.layout, builder: (column) => column);
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $LibraryFoldersTable,
          LibraryFolder,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (
            LibraryFolder,
            BaseReferences<
              _$KyndrelDatabase,
              $LibraryFoldersTable,
              LibraryFolder
            >,
          ),
          LibraryFolder,
          PrefetchHooks Function()
        > {
  $$LibraryFoldersTableTableManager(
    _$KyndrelDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> private = const Value.absent(),
                Value<String?> sort = const Value.absent(),
                Value<bool?> descending = const Value.absent(),
                Value<String?> layout = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion(
                path: path,
                hidden: hidden,
                pinned: pinned,
                private: private,
                sort: sort,
                descending: descending,
                layout: layout,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                Value<bool> hidden = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> private = const Value.absent(),
                Value<String?> sort = const Value.absent(),
                Value<bool?> descending = const Value.absent(),
                Value<String?> layout = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion.insert(
                path: path,
                hidden: hidden,
                pinned: pinned,
                private: private,
                sort: sort,
                descending: descending,
                layout: layout,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, LibraryFolder>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $LibraryFoldersTable,
                    LibraryFolder
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $LibraryFoldersTable,
      LibraryFolder,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (
        LibraryFolder,
        BaseReferences<_$KyndrelDatabase, $LibraryFoldersTable, LibraryFolder>,
      ),
      LibraryFolder,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  required String source,
  required int positionMs,
  required String label,
  required DateTime createdAt,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<int> positionMs,
  Value<String> label,
  Value<DateTime> createdAt,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$KyndrelDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            Bookmark,
            BaseReferences<_$KyndrelDatabase, $BookmarksTable, Bookmark>,
          ),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$KyndrelDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                source: source,
                positionMs: positionMs,
                label: label,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required int positionMs,
                required String label,
                required DateTime createdAt,
              }) => BookmarksCompanion.insert(
                id: id,
                source: source,
                positionMs: positionMs,
                label: label,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, Bookmark>(table),
                  BaseReferences<_$KyndrelDatabase, $BookmarksTable, Bookmark>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$KyndrelDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$SavedPlaylistsTableCreateCompanionBuilder =
    SavedPlaylistsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$SavedPlaylistsTableUpdateCompanionBuilder =
    SavedPlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$SavedPlaylistsTableReferences
    extends
        BaseReferences<_$KyndrelDatabase, $SavedPlaylistsTable, SavedPlaylist> {
  $$SavedPlaylistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SavedPlaylistItemsTable, List<SavedPlaylistItem>>
  _savedPlaylistItemsRefsTable(_$KyndrelDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedPlaylistItems,
        aliasName: 'saved_playlists__id__saved_playlist_items__playlist_id',
      );

  $$SavedPlaylistItemsTableProcessedTableManager get savedPlaylistItemsRefs {
    final manager = $$SavedPlaylistItemsTableTableManager(
      $_db,
      $_db.savedPlaylistItems,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedPlaylistItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedPlaylistsTableFilterComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistsTable> {
  $$SavedPlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedPlaylistItemsRefs(
    Expression<bool> Function($$SavedPlaylistItemsTableFilterComposer f) f,
  ) {
    final $$SavedPlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedPlaylistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedPlaylistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedPlaylistsTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistsTable> {
  $$SavedPlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedPlaylistsTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistsTable> {
  $$SavedPlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> savedPlaylistItemsRefs<T extends Object>(
    Expression<T> Function($$SavedPlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedPlaylistItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedPlaylistItems,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedPlaylistItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedPlaylistItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedPlaylistsTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $SavedPlaylistsTable,
          SavedPlaylist,
          $$SavedPlaylistsTableFilterComposer,
          $$SavedPlaylistsTableOrderingComposer,
          $$SavedPlaylistsTableAnnotationComposer,
          $$SavedPlaylistsTableCreateCompanionBuilder,
          $$SavedPlaylistsTableUpdateCompanionBuilder,
          (SavedPlaylist, $$SavedPlaylistsTableReferences),
          SavedPlaylist,
          PrefetchHooks Function({bool savedPlaylistItemsRefs})
        > {
  $$SavedPlaylistsTableTableManager(
    _$KyndrelDatabase db,
    $SavedPlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SavedPlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => SavedPlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedPlaylistsTable, SavedPlaylist>(table),
                  $$SavedPlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedPlaylistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedPlaylistItemsRefs) db.savedPlaylistItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedPlaylistItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      SavedPlaylist,
                      $SavedPlaylistsTable,
                      SavedPlaylistItem,
                      $SavedPlaylistItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SavedPlaylistsTableReferences
                          ._savedPlaylistItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedPlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedPlaylistItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedPlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $SavedPlaylistsTable,
      SavedPlaylist,
      $$SavedPlaylistsTableFilterComposer,
      $$SavedPlaylistsTableOrderingComposer,
      $$SavedPlaylistsTableAnnotationComposer,
      $$SavedPlaylistsTableCreateCompanionBuilder,
      $$SavedPlaylistsTableUpdateCompanionBuilder,
      (SavedPlaylist, $$SavedPlaylistsTableReferences),
      SavedPlaylist,
      PrefetchHooks Function({bool savedPlaylistItemsRefs})
    >;
typedef $$SavedPlaylistItemsTableCreateCompanionBuilder =
    SavedPlaylistItemsCompanion Function({
      required int playlistId,
      required int position,
      required String uri,
      Value<int> rowid,
    });
typedef $$SavedPlaylistItemsTableUpdateCompanionBuilder =
    SavedPlaylistItemsCompanion Function({
      Value<int> playlistId,
      Value<int> position,
      Value<String> uri,
      Value<int> rowid,
    });

final class $$SavedPlaylistItemsTableReferences
    extends
        BaseReferences<
          _$KyndrelDatabase,
          $SavedPlaylistItemsTable,
          SavedPlaylistItem
        > {
  $$SavedPlaylistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedPlaylistsTable _playlistIdTable(_$KyndrelDatabase db) => db
      .savedPlaylists
      .createAlias('saved_playlist_items__playlist_id__saved_playlists__id');

  $$SavedPlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$SavedPlaylistsTableTableManager(
      $_db,
      $_db.savedPlaylists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedPlaylistItemsTableFilterComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistItemsTable> {
  $$SavedPlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedPlaylistsTableFilterComposer get playlistId {
    final $$SavedPlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.savedPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.savedPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPlaylistItemsTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistItemsTable> {
  $$SavedPlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedPlaylistsTableOrderingComposer get playlistId {
    final $$SavedPlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.savedPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.savedPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPlaylistItemsTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $SavedPlaylistItemsTable> {
  $$SavedPlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  $$SavedPlaylistsTableAnnotationComposer get playlistId {
    final $$SavedPlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.savedPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $SavedPlaylistItemsTable,
          SavedPlaylistItem,
          $$SavedPlaylistItemsTableFilterComposer,
          $$SavedPlaylistItemsTableOrderingComposer,
          $$SavedPlaylistItemsTableAnnotationComposer,
          $$SavedPlaylistItemsTableCreateCompanionBuilder,
          $$SavedPlaylistItemsTableUpdateCompanionBuilder,
          (SavedPlaylistItem, $$SavedPlaylistItemsTableReferences),
          SavedPlaylistItem,
          PrefetchHooks Function({bool playlistId})
        > {
  $$SavedPlaylistItemsTableTableManager(
    _$KyndrelDatabase db,
    $SavedPlaylistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPlaylistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedPlaylistItemsCompanion(
                playlistId: playlistId,
                position: position,
                uri: uri,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required int position,
                required String uri,
                Value<int> rowid = const Value.absent(),
              }) => SavedPlaylistItemsCompanion.insert(
                playlistId: playlistId,
                position: position,
                uri: uri,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedPlaylistItemsTable, SavedPlaylistItem>(
                    table,
                  ),
                  $$SavedPlaylistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$SavedPlaylistItemsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$SavedPlaylistItemsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedPlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $SavedPlaylistItemsTable,
      SavedPlaylistItem,
      $$SavedPlaylistItemsTableFilterComposer,
      $$SavedPlaylistItemsTableOrderingComposer,
      $$SavedPlaylistItemsTableAnnotationComposer,
      $$SavedPlaylistItemsTableCreateCompanionBuilder,
      $$SavedPlaylistItemsTableUpdateCompanionBuilder,
      (SavedPlaylistItem, $$SavedPlaylistItemsTableReferences),
      SavedPlaylistItem,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$FileSettingsTableCreateCompanionBuilder =
    FileSettingsCompanion Function({
      required String source,
      required String json,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FileSettingsTableUpdateCompanionBuilder =
    FileSettingsCompanion Function({
      Value<String> source,
      Value<String> json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$FileSettingsTableFilterComposer
    extends Composer<_$KyndrelDatabase, $FileSettingsTable> {
  $$FileSettingsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileSettingsTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $FileSettingsTable> {
  $$FileSettingsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileSettingsTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $FileSettingsTable> {
  $$FileSettingsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FileSettingsTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $FileSettingsTable,
          FileSetting,
          $$FileSettingsTableFilterComposer,
          $$FileSettingsTableOrderingComposer,
          $$FileSettingsTableAnnotationComposer,
          $$FileSettingsTableCreateCompanionBuilder,
          $$FileSettingsTableUpdateCompanionBuilder,
          (
            FileSetting,
            BaseReferences<_$KyndrelDatabase, $FileSettingsTable, FileSetting>,
          ),
          FileSetting,
          PrefetchHooks Function()
        > {
  $$FileSettingsTableTableManager(
    _$KyndrelDatabase db,
    $FileSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileSettingsCompanion(
                source: source,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required String json,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileSettingsCompanion.insert(
                source: source,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FileSettingsTable, FileSetting>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $FileSettingsTable,
                    FileSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $FileSettingsTable,
      FileSetting,
      $$FileSettingsTableFilterComposer,
      $$FileSettingsTableOrderingComposer,
      $$FileSettingsTableAnnotationComposer,
      $$FileSettingsTableCreateCompanionBuilder,
      $$FileSettingsTableUpdateCompanionBuilder,
      (
        FileSetting,
        BaseReferences<_$KyndrelDatabase, $FileSettingsTable, FileSetting>,
      ),
      FileSetting,
      PrefetchHooks Function()
    >;
typedef $$ReplaysTableCreateCompanionBuilder = ReplaysCompanion Function({
  required String source,
  required int bucket,
  Value<int> count,
  Value<int> rowid,
});
typedef $$ReplaysTableUpdateCompanionBuilder = ReplaysCompanion Function({
  Value<String> source,
  Value<int> bucket,
  Value<int> count,
  Value<int> rowid,
});

class $$ReplaysTableFilterComposer
    extends Composer<_$KyndrelDatabase, $ReplaysTable> {
  $$ReplaysTableFilterComposer({
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

  ColumnFilters<int> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReplaysTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $ReplaysTable> {
  $$ReplaysTableOrderingComposer({
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

  ColumnOrderings<int> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReplaysTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $ReplaysTable> {
  $$ReplaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$ReplaysTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $ReplaysTable,
          Replay,
          $$ReplaysTableFilterComposer,
          $$ReplaysTableOrderingComposer,
          $$ReplaysTableAnnotationComposer,
          $$ReplaysTableCreateCompanionBuilder,
          $$ReplaysTableUpdateCompanionBuilder,
          (Replay, BaseReferences<_$KyndrelDatabase, $ReplaysTable, Replay>),
          Replay,
          PrefetchHooks Function()
        > {
  $$ReplaysTableTableManager(_$KyndrelDatabase db, $ReplaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReplaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReplaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReplaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<int> bucket = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReplaysCompanion(
                source: source,
                bucket: bucket,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required int bucket,
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReplaysCompanion.insert(
                source: source,
                bucket: bucket,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReplaysTable, Replay>(table),
                  BaseReferences<_$KyndrelDatabase, $ReplaysTable, Replay>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReplaysTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $ReplaysTable,
      Replay,
      $$ReplaysTableFilterComposer,
      $$ReplaysTableOrderingComposer,
      $$ReplaysTableAnnotationComposer,
      $$ReplaysTableCreateCompanionBuilder,
      $$ReplaysTableUpdateCompanionBuilder,
      (Replay, BaseReferences<_$KyndrelDatabase, $ReplaysTable, Replay>),
      Replay,
      PrefetchHooks Function()
    >;
typedef $$IntroMarksTableCreateCompanionBuilder = IntroMarksCompanion Function({
  required String show,
  Value<int?> introStartMs,
  Value<int?> introEndMs,
  Value<int?> creditsFromEndMs,
  Value<bool> manual,
  Value<int> rowid,
});
typedef $$IntroMarksTableUpdateCompanionBuilder = IntroMarksCompanion Function({
  Value<String> show,
  Value<int?> introStartMs,
  Value<int?> introEndMs,
  Value<int?> creditsFromEndMs,
  Value<bool> manual,
  Value<int> rowid,
});

class $$IntroMarksTableFilterComposer
    extends Composer<_$KyndrelDatabase, $IntroMarksTable> {
  $$IntroMarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get introStartMs => $composableBuilder(
    column: $table.introStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get introEndMs => $composableBuilder(
    column: $table.introEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditsFromEndMs => $composableBuilder(
    column: $table.creditsFromEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntroMarksTableOrderingComposer
    extends Composer<_$KyndrelDatabase, $IntroMarksTable> {
  $$IntroMarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get introStartMs => $composableBuilder(
    column: $table.introStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get introEndMs => $composableBuilder(
    column: $table.introEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditsFromEndMs => $composableBuilder(
    column: $table.creditsFromEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntroMarksTableAnnotationComposer
    extends Composer<_$KyndrelDatabase, $IntroMarksTable> {
  $$IntroMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get show =>
      $composableBuilder(column: $table.show, builder: (column) => column);

  GeneratedColumn<int> get introStartMs => $composableBuilder(
    column: $table.introStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get introEndMs => $composableBuilder(
    column: $table.introEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditsFromEndMs => $composableBuilder(
    column: $table.creditsFromEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get manual =>
      $composableBuilder(column: $table.manual, builder: (column) => column);
}

class $$IntroMarksTableTableManager
    extends
        RootTableManager<
          _$KyndrelDatabase,
          $IntroMarksTable,
          IntroMark,
          $$IntroMarksTableFilterComposer,
          $$IntroMarksTableOrderingComposer,
          $$IntroMarksTableAnnotationComposer,
          $$IntroMarksTableCreateCompanionBuilder,
          $$IntroMarksTableUpdateCompanionBuilder,
          (
            IntroMark,
            BaseReferences<_$KyndrelDatabase, $IntroMarksTable, IntroMark>,
          ),
          IntroMark,
          PrefetchHooks Function()
        > {
  $$IntroMarksTableTableManager(_$KyndrelDatabase db, $IntroMarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntroMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntroMarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntroMarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> show = const Value.absent(),
                Value<int?> introStartMs = const Value.absent(),
                Value<int?> introEndMs = const Value.absent(),
                Value<int?> creditsFromEndMs = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntroMarksCompanion(
                show: show,
                introStartMs: introStartMs,
                introEndMs: introEndMs,
                creditsFromEndMs: creditsFromEndMs,
                manual: manual,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String show,
                Value<int?> introStartMs = const Value.absent(),
                Value<int?> introEndMs = const Value.absent(),
                Value<int?> creditsFromEndMs = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntroMarksCompanion.insert(
                show: show,
                introStartMs: introStartMs,
                introEndMs: introEndMs,
                creditsFromEndMs: creditsFromEndMs,
                manual: manual,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IntroMarksTable, IntroMark>(table),
                  BaseReferences<
                    _$KyndrelDatabase,
                    $IntroMarksTable,
                    IntroMark
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IntroMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$KyndrelDatabase,
      $IntroMarksTable,
      IntroMark,
      $$IntroMarksTableFilterComposer,
      $$IntroMarksTableOrderingComposer,
      $$IntroMarksTableAnnotationComposer,
      $$IntroMarksTableCreateCompanionBuilder,
      $$IntroMarksTableUpdateCompanionBuilder,
      (
        IntroMark,
        BaseReferences<_$KyndrelDatabase, $IntroMarksTable, IntroMark>,
      ),
      IntroMark,
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
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$SavedPlaylistsTableTableManager get savedPlaylists =>
      $$SavedPlaylistsTableTableManager(_db, _db.savedPlaylists);
  $$SavedPlaylistItemsTableTableManager get savedPlaylistItems =>
      $$SavedPlaylistItemsTableTableManager(_db, _db.savedPlaylistItems);
  $$FileSettingsTableTableManager get fileSettings =>
      $$FileSettingsTableTableManager(_db, _db.fileSettings);
  $$ReplaysTableTableManager get replays =>
      $$ReplaysTableTableManager(_db, _db.replays);
  $$IntroMarksTableTableManager get introMarks =>
      $$IntroMarksTableTableManager(_db, _db.introMarks);
}
