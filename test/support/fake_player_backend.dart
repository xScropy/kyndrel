import 'dart:async';

import 'package:kyndrel/core/player/player_backend.dart';

/// In-memory [PlayerBackend]. Tests push events with the `emit*` methods and
/// inspect [calls] to see which commands the service sent.
class FakePlayerBackend implements PlayerBackend {
  final calls = <String>[];
  final properties = <String, String>{};
  bool disposed = false;

  final _playing = StreamController<bool>.broadcast(sync: true);
  final _completed = StreamController<bool>.broadcast(sync: true);
  final _buffering = StreamController<bool>.broadcast(sync: true);
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration>.broadcast(sync: true);
  final _buffer = StreamController<Duration>.broadcast(sync: true);
  final _width = StreamController<int?>.broadcast(sync: true);
  final _height = StreamController<int?>.broadcast(sync: true);
  final _error = StreamController<String>.broadcast(sync: true);

  void emitPlaying({required bool value}) => _playing.add(value);
  void emitCompleted({required bool value}) => _completed.add(value);
  void emitBuffering({required bool value}) => _buffering.add(value);
  void emitPosition(Duration v) => _position.add(v);
  void emitDuration(Duration v) => _duration.add(v);
  void emitBuffer(Duration v) => _buffer.add(v);
  void emitSize(int w, int h) {
    _width.add(w);
    _height.add(h);
  }

  void emitError(String v) => _error.add(v);

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<Duration> get buffer => _buffer.stream;
  @override
  Stream<int?> get width => _width.stream;
  @override
  Stream<int?> get height => _height.stream;
  @override
  Stream<String> get error => _error.stream;

  @override
  Future<void> open(String source, {required bool play}) async =>
      calls.add('open($source, play: $play)');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek(${position.inMilliseconds})');

  @override
  Future<String?> getProperty(String name) async => properties[name];

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}
