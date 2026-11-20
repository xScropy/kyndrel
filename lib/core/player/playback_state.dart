import 'package:flutter/foundation.dart';

/// High-level phase of the player, derived from libmpv's raw flags.
enum PlaybackStatus {
  /// Nothing opened yet.
  idle,

  /// A source was opened and is not ready to show yet.
  loading,

  /// Ready and playing.
  playing,

  /// Ready and paused.
  paused,

  /// Reached the end of the file.
  completed,

  /// libmpv reported an error for the current source.
  error,
}

/// Immutable snapshot of everything the UI needs to draw playback.
@immutable
class PlaybackState {
  const new({
    this.source,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.isLoaded = false,
    this.endedEarly = false,
    this.videoWidth,
    this.videoHeight,
    this.errorMessage,
    this.volume = 100,
    this.isMuted = false,
    this.rate = 1,
  });

  /// File path or URL currently opened, or null when idle.
  final String? source;
  final Duration position;

  /// Zero until known; stays zero for live streams.
  final Duration duration;

  /// How far ahead of [position] the demuxer cache reaches.
  final Duration buffered;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;

  /// True once libmpv has reported something that proves the file is open:
  /// a duration or a video size.
  final bool isLoaded;

  /// Playback stopped well before the end (a dropped stream or a truncated
  /// file). With [errorMessage] this makes [status] an error, so the film
  /// isn't counted as watched.
  final bool endedEarly;
  final int? videoWidth;
  final int? videoHeight;

  /// Last error mpv logged for this source. media_kit forwards every
  /// error-level log line, including non-fatal ones ("could not open audio
  /// device"), so this alone does not mean playback failed; see [status].
  final String? errorMessage;

  /// 0–400 (mpv `volume`, with `volume-max=400`).
  final double volume;
  final bool isMuted;

  /// Playback speed (mpv `speed`).
  final double rate;

  static const PlaybackState initial = PlaybackState();

  PlaybackStatus get status {
    // An error is fatal only if the source never loaded or playback was
    // cut short. Other errors after loading are warnings (playback carries
    // on).
    if (errorMessage != null && (!isLoaded || endedEarly)) {
      return PlaybackStatus.error;
    }
    if (source == null) return PlaybackStatus.idle;
    if (isCompleted) return PlaybackStatus.completed;
    if (!isLoaded) return PlaybackStatus.loading;
    return isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused;
  }

  PlaybackState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    bool? isLoaded,
    bool? endedEarly,
    int? videoWidth,
    int? videoHeight,
    String? errorMessage,
    double? volume,
    bool? isMuted,
    double? rate,
  }) {
    return PlaybackState(
      source: source,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      isLoaded: isLoaded ?? this.isLoaded,
      endedEarly: endedEarly ?? this.endedEarly,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      errorMessage: errorMessage ?? this.errorMessage,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      rate: rate ?? this.rate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.source == source &&
      other.position == position &&
      other.duration == duration &&
      other.buffered == buffered &&
      other.isPlaying == isPlaying &&
      other.isBuffering == isBuffering &&
      other.isCompleted == isCompleted &&
      other.isLoaded == isLoaded &&
      other.endedEarly == endedEarly &&
      other.videoWidth == videoWidth &&
      other.videoHeight == videoHeight &&
      other.errorMessage == errorMessage &&
      other.volume == volume &&
      other.isMuted == isMuted &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(
    source,
    position,
    duration,
    buffered,
    isPlaying,
    isBuffering,
    isCompleted,
    isLoaded,
    endedEarly,
    videoWidth,
    videoHeight,
    errorMessage,
    volume,
    isMuted,
    rate,
  );

  @override
  String toString() =>
      'PlaybackState($status, $position/$duration, source: $source)';
}

/// How loud the music is now, 0–1 (task 7.6).
@immutable
class AudioLevel {
  const new(this.rms, this.peak);

  /// From mpv's `astats` metadata (JSON with levels in dB); quiet below
  /// -60 dB.
  factory parse(String? json) {
    if (json == null) return silent;
    double level(String key) {
      final m = RegExp('"lavfi.astats.Overall.$key":"([^"]+)"')
          .firstMatch(json);
      final db = double.tryParse(m?.group(1) ?? '');
      if (db == null || db.isNaN) return 0;
      return ((db + 60) / 60).clamp(0.0, 1.0);
    }

    return AudioLevel(level('RMS_level'), level('Peak_level'));
  }

  static const silent = AudioLevel(0, 0);

  /// Average loudness.
  final double rms;

  /// Loudest moment.
  final double peak;
}
