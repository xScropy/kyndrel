import 'package:flutter/foundation.dart';

/// What a cast device reports about playback.
@immutable
class RemoteStatus {
  const new({
    required this.position,
    required this.playing,
    this.duration,
    this.finished = false,
  });

  final Duration position;
  final bool playing;
  final Duration? duration;
  final bool finished;
}

/// A device that plays the current file instead of the local player (cast,
/// task 4.4). While one is attached, `PlayerService` sends play, pause,
/// seek and volume to it and takes position and state from it.
abstract interface class RemoteTarget {
  String get name;
  Stream<RemoteStatus> get status;
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// [volume] in 0–1.
  Future<void> setVolume(double volume);
  Future<void> stop();
}
