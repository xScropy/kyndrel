import 'package:flutter/foundation.dart';

enum MediaTrackType { video, audio, subtitle }

/// One entry of mpv's `track-list`.
@immutable
class MediaTrack {
  const new({
    required this.id,
    required this.type,
    this.title,
    this.language,
    this.codec,
    this.isExternal = false,
    this.externalFilename,
    this.isDefault = false,
    this.isForced = false,
    this.channels,
    this.isCoverArt = false,
  });

  /// mpv track id (per type), as used by `aid`/`sid`.
  final int id;
  final MediaTrackType type;
  final String? title;

  /// ISO 639 code as stored in the file (`eng`, `en`, `ara`...).
  final String? language;
  final String? codec;
  final bool isExternal;
  final String? externalFilename;
  final bool isDefault;
  final bool isForced;

  /// Audio channel count.
  final int? channels;

  /// A song's picture rather than a real video track (task 7.6).
  final bool isCoverArt;

  /// Bitmap subtitle formats (PGS, VobSub, DVB) that libass can't restyle.
  bool get isImageSubtitle => const {
    'hdmv_pgs_subtitle',
    'dvd_subtitle',
    'dvb_subtitle',
    'pgs',
    'vobsub',
  }.contains(codec);

  @override
  bool operator ==(Object other) =>
      other is MediaTrack &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.language == language &&
      other.codec == codec &&
      other.isExternal == isExternal &&
      other.externalFilename == externalFilename &&
      other.isDefault == isDefault &&
      other.isForced == isForced &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    language,
    codec,
    isExternal,
    externalFilename,
    isDefault,
    isForced,
    channels,
  );

  @override
  String toString() => 'MediaTrack(${type.name} #$id $language $title)';
}

/// A chapter mark (task 3.6).
@immutable
class Chapter {
  const new({required this.start, this.title});

  final Duration start;
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is Chapter && other.start == start && other.title == title;

  @override
  int get hashCode => Object.hash(start, title);
}

/// Tracks and the per-file sync offsets.
@immutable
class TrackState {
  const new({
    this.video = const [],
    this.audio = const [],
    this.subtitles = const [],
    this.audioId,
    this.subtitleId,
    this.secondarySubtitleId,
    this.subtitleDelay = Duration.zero,
    this.audioDelay = Duration.zero,
    this.chapters = const [],
    this.chapterIndex,
    this.loopA,
    this.loopB,
  });

  final List<MediaTrack> video;
  final List<MediaTrack> audio;

  /// Music: sound and at most a cover picture (task 7.6).
  bool get isAudioOnly => audio.isNotEmpty && video.every((v) => v.isCoverArt);
  final List<MediaTrack> subtitles;

  /// Selected ids; null means none ("no").
  final int? audioId;
  final int? subtitleId;
  final int? secondarySubtitleId;

  /// Positive delays show subtitles / play audio later.
  final Duration subtitleDelay;
  final Duration audioDelay;

  final List<Chapter> chapters;

  /// Current chapter, or null before the first / without chapters.
  final int? chapterIndex;

  /// A-B loop points (task 3.9); null when unset.
  final Duration? loopA;
  final Duration? loopB;

  static const TrackState empty = TrackState();

  /// The chapter containing [position], if any.
  Chapter? chapterAt(Duration position) {
    Chapter? found;
    for (final c in chapters) {
      if (c.start <= position) found = c;
    }
    return found;
  }

  MediaTrack? get selectedSubtitle =>
      subtitles.where((t) => t.id == subtitleId).firstOrNull;

  TrackState copyWith({
    List<MediaTrack>? video,
    List<MediaTrack>? audio,
    List<MediaTrack>? subtitles,
    int? Function()? audioId,
    int? Function()? subtitleId,
    int? Function()? secondarySubtitleId,
    Duration? subtitleDelay,
    Duration? audioDelay,
    List<Chapter>? chapters,
    int? Function()? chapterIndex,
    Duration? Function()? loopA,
    Duration? Function()? loopB,
  }) {
    return TrackState(
      video: video ?? this.video,
      audio: audio ?? this.audio,
      subtitles: subtitles ?? this.subtitles,
      audioId: audioId != null ? audioId() : this.audioId,
      subtitleId: subtitleId != null ? subtitleId() : this.subtitleId,
      secondarySubtitleId: secondarySubtitleId != null
          ? secondarySubtitleId()
          : this.secondarySubtitleId,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      audioDelay: audioDelay ?? this.audioDelay,
      chapters: chapters ?? this.chapters,
      chapterIndex: chapterIndex != null ? chapterIndex() : this.chapterIndex,
      loopA: loopA != null ? loopA() : this.loopA,
      loopB: loopB != null ? loopB() : this.loopB,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackState &&
      listEquals(other.video, video) &&
      listEquals(other.audio, audio) &&
      listEquals(other.subtitles, subtitles) &&
      other.audioId == audioId &&
      other.subtitleId == subtitleId &&
      other.secondarySubtitleId == secondarySubtitleId &&
      other.subtitleDelay == subtitleDelay &&
      other.audioDelay == audioDelay &&
      listEquals(other.chapters, chapters) &&
      other.chapterIndex == chapterIndex &&
      other.loopA == loopA &&
      other.loopB == loopB;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(video),
    Object.hashAll(audio),
    Object.hashAll(subtitles),
    audioId,
    subtitleId,
    secondarySubtitleId,
    subtitleDelay,
    audioDelay,
    Object.hashAll(chapters),
    chapterIndex,
    loopA,
    loopB,
  );
}
