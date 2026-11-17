import 'dart:async';

import 'package:kyndrel/core/player/player_backend.dart';

/// In-memory [PlayerBackend]. Tests push events with the `emit*` methods and
/// inspect [calls] to see which commands the service sent.
///
/// `setProperty` stores values in [properties] and echoes them to
/// [observe] listeners, like mpv does.
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
  final _volume = StreamController<double>.broadcast(sync: true);
  final _rate = StreamController<double>.broadcast(sync: true);
  final _error = StreamController<String>.broadcast(sync: true);
  final _log = StreamController<PlayerLogLine>.broadcast(sync: true);
  final _tracks = StreamController<void>.broadcast(sync: true);
  final _observed = <String, StreamController<String>>{};

  /// Commands other than property sets, e.g. `['sub-add', 'a.srt', 'select']`.
  List<List<String>> get commands => _commands;
  final _commands = <List<String>>[];

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

  void emitVolume(double v) => _volume.add(v);
  void emitRate(double v) => _rate.add(v);
  void emitError(String v) => _error.add(v);
  void emitLog(String level, String prefix, String text) =>
      _log.add((level: level, prefix: prefix, text: text));

  /// Sets mpv-style `track-list/N/...` properties and fires tracksChanged.
  void emitTracks(List<Map<String, String>> tracks) {
    properties.removeWhere((k, _) => k.startsWith('track-list/'));
    properties['track-list/count'] = '${tracks.length}';
    for (var i = 0; i < tracks.length; i++) {
      for (final e in tracks[i].entries) {
        properties['track-list/$i/${e.key}'] = e.value;
      }
    }
    _tracks.add(null);
  }

  /// Simulates mpv changing a property by itself.
  void emitProperty(String name, String value) {
    properties[name] = value;
    _observed[name]?.add(value);
  }

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
  Stream<double> get volume => _volume.stream;
  @override
  Stream<double> get rate => _rate.stream;
  @override
  Stream<String> get error => _error.stream;
  @override
  Stream<PlayerLogLine> get log => _log.stream;
  @override
  Stream<void> get tracksChanged => _tracks.stream;

  @override
  Stream<String> observe(String property) => _observed
      .putIfAbsent(property, () => StreamController.broadcast(sync: true))
      .stream;

  @override
  Future<void> open(String source, {required bool play}) async =>
      calls.add('open($source, play: $play)');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek(${position.inMilliseconds})');

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume($volume)');
    _volume.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('rate($rate)');
    _rate.add(rate);
  }

  @override
  Future<String?> getProperty(String name) async => properties[name];

  @override
  Future<void> setProperty(String name, String value) async {
    emitProperty(name, value);
  }

  /// Lets a test react to commands like mpv would (e.g. sub-add adding a
  /// track).
  void Function(List<String> args)? onCommand;

  @override
  Future<void> command(List<String> args) async {
    _commands.add(args);
    onCommand?.call(args);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}
