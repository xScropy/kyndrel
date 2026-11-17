import 'dart:async';

import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_backend.dart';

/// The single entry point to the playback engine (PLAN.md §2).
///
/// Turns the backend's separate raw streams into one [PlaybackState] and
/// exposes the commands the UI needs. UI code reads it through the Riverpod
/// providers in `player_providers.dart`.
class PlayerService {
  new(this.backend) {
    _subscriptions.addAll([
      backend.playing.listen(
        (v) => _update(
          _state.copyWith(isPlaying: v, isLoaded: v || _state.isLoaded),
        ),
      ),
      backend.completed.listen((v) => _update(_state.copyWith(isCompleted: v))),
      backend.buffering.listen((v) => _update(_state.copyWith(isBuffering: v))),
      backend.position.listen((v) => _update(_state.copyWith(position: v))),
      backend.duration.listen(
        (v) => _update(
          _state.copyWith(
            duration: v,
            isLoaded: v > Duration.zero || _state.isLoaded,
          ),
        ),
      ),
      backend.buffer.listen((v) => _update(_state.copyWith(buffered: v))),
      backend.width.listen(
        (v) => _update(
          _state.copyWith(
            videoWidth: v,
            isLoaded: v != null || _state.isLoaded,
          ),
        ),
      ),
      backend.height.listen((v) => _update(_state.copyWith(videoHeight: v))),
      backend.error.listen(_onError),
    ]);
  }

  /// Exposed only so `PlayerVideoView` can reach the video surface.
  final PlayerBackend backend;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _controller = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = PlaybackState.initial;
  bool _disposed = false;

  /// Current snapshot.
  PlaybackState get state => _state;

  /// Every state change, starting with the current state.
  ///
  /// Subscribes to live changes as soon as it is listened to, so nothing
  /// emitted between the replay and the subscription is lost.
  Stream<PlaybackState> get states => Stream.multi((listener) {
    listener.add(_state);
    final sub = _controller.stream.listen(
      listener.addSync,
      onDone: listener.closeSync,
    );
    listener.onCancel = sub.cancel;
  });

  Stream<Duration> get position => states.map((s) => s.position).distinct();
  Stream<Duration> get duration => states.map((s) => s.duration).distinct();
  Stream<bool> get buffering => states.map((s) => s.isBuffering).distinct();
  Stream<PlaybackStatus> get status => states.map((s) => s.status).distinct();

  /// Opens a local path or URL. Starts playing unless [play] is false.
  Future<void> open(String source, {bool play = true}) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(source, 'source', 'must not be empty');
    }
    _update(PlaybackState(source: trimmed));
    await backend.open(trimmed, play: play);
  }

  Future<void> play() async {
    if (_state.source == null) return;
    // Pressing play at the end restarts from the beginning, like most players.
    if (_state.isCompleted) await backend.seek(Duration.zero);
    await backend.play();
  }

  Future<void> pause() => backend.pause();

  Future<void> playOrPause() => _state.isPlaying ? pause() : play();

  /// Seeks to [position], clamped to the file's length when it is known.
  Future<void> seek(Duration position) async {
    if (_state.source == null) return;
    await backend.seek(_clamp(position));
  }

  /// Seeks relative to the current position (negative goes back).
  Future<void> seekBy(Duration offset) => seek(_state.position + offset);

  /// The hardware decoder mpv is using (e.g. `d3d11va`), or null if decoding
  /// in software or unknown.
  Future<String?> hardwareDecoder() async {
    final value = await backend.getProperty('hwdec-current');
    if (value == null || value.isEmpty || value == 'no') return null;
    return value;
  }

  /// mpv properties shown in the diagnostics overlay (`--diagnostics`).
  static const diagnosticProperties = [
    'hwdec-current',
    'video-codec',
    'width',
    'height',
    'container-fps',
    'estimated-vf-fps',
    'frame-drop-count',
  ];

  /// Current values of [diagnosticProperties]; unavailable ones are omitted.
  Future<Map<String, String>> diagnostics() async {
    final values = <String, String>{};
    for (final name in diagnosticProperties) {
      final v = await backend.getProperty(name);
      if (v != null) values[name] = v;
    }
    return values;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _controller.close();
    await backend.dispose();
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final d = _state.duration;
    if (d > Duration.zero && position > d) return d;
    return position;
  }

  void _onError(String message) {
    if (message.trim().isEmpty) return;
    _update(_state.copyWith(errorMessage: message));
  }

  void _update(PlaybackState next) {
    if (_disposed || next == _state) return;
    _state = next;
    _controller.add(next);
  }
}
