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
    this.videoWidth,
    this.videoHeight,
    this.errorMessage,
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

  /// True once libmpv has reported anything that proves the file is open
  /// (a duration, a video size, or playback starting).
  final bool isLoaded;
  final int? videoWidth;
  final int? videoHeight;

  /// Last error mpv logged for this source. media_kit forwards every
  /// error-level log line, including non-fatal ones ("could not open audio
  /// device"), so this alone does not mean playback failed; see [status].
  final String? errorMessage;

  static const PlaybackState initial = PlaybackState();

  PlaybackStatus get status {
    // An error is fatal only if the source never loaded. Errors after that
    // are warnings (playback carries on).
    if (errorMessage != null && !isLoaded) return PlaybackStatus.error;
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
    int? videoWidth,
    int? videoHeight,
    String? errorMessage,
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
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      errorMessage: errorMessage ?? this.errorMessage,
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
      other.videoWidth == videoWidth &&
      other.videoHeight == videoHeight &&
      other.errorMessage == errorMessage;

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
    videoWidth,
    videoHeight,
    errorMessage,
  );

  @override
  String toString() =>
      'PlaybackState($status, $position/$duration, source: $source)';
}
