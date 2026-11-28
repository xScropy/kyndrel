import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

/// What a file remembers between plays (task 8.8), like SMPlayer and Next
/// Player: its tracks, speed, delays and picture.
@immutable
class PerFileSettings {
  const new({
    this.audioId,
    this.subtitleId,
    this.secondarySubtitleId,
    this.rate = 1,
    this.subtitleDelay = Duration.zero,
    this.audioDelay = Duration.zero,
    this.fit,
    this.zoom = 1,
    this.rotation = 0,
  });

  factory fromJson(Map<String, Object?> j) => PerFileSettings(
    audioId: (j['aid'] as num?)?.toInt(),
    subtitleId: (j['sid'] as num?)?.toInt(),
    secondarySubtitleId: (j['sid2'] as num?)?.toInt(),
    rate: (j['rate'] as num?)?.toDouble() ?? 1,
    subtitleDelay: Duration(
      milliseconds: (j['subDelayMs'] as num?)?.toInt() ?? 0,
    ),
    audioDelay: Duration(
      milliseconds: (j['audioDelayMs'] as num?)?.toInt() ?? 0,
    ),
    fit: j['fit'] as String?,
    zoom: (j['zoom'] as num?)?.toDouble() ?? 1,
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
  );

  final int? audioId;

  /// The subtitle track; [noSubtitles] when turned off.
  final int? subtitleId;
  final int? secondarySubtitleId;
  final double rate;
  final Duration subtitleDelay;
  final Duration audioDelay;

  /// `VideoFit` name.
  final String? fit;
  final double zoom;
  final int rotation;

  static const noSubtitles = -1;

  Map<String, Object?> toJson() => {
    'aid': audioId,
    'sid': subtitleId,
    'sid2': secondarySubtitleId,
    'rate': rate,
    'subDelayMs': subtitleDelay.inMilliseconds,
    'audioDelayMs': audioDelay.inMilliseconds,
    'fit': fit,
    'zoom': zoom,
    'rotation': rotation,
  };

  @override
  bool operator ==(Object other) =>
      other is PerFileSettings &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class FileSettingsRepository {
  new(this._db);

  final KyndrelDatabase _db;

  Future<PerFileSettings?> get(String source) async {
    final row = await (_db.select(
      _db.fileSettings,
    )..where((t) => t.source.equals(source))).getSingleOrNull();
    if (row == null) return null;
    try {
      return PerFileSettings.fromJson(
        jsonDecode(row.json) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String source, PerFileSettings settings) => _db
      .into(_db.fileSettings)
      .insertOnConflictUpdate(
        FileSettingsCompanion.insert(
          source: source,
          json: jsonEncode(settings.toJson()),
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> clear() => _db.delete(_db.fileSettings).go();
}

final fileSettingsRepositoryProvider = Provider<FileSettingsRepository>(
  (ref) => FileSettingsRepository(ref.watch(databaseProvider)),
);
