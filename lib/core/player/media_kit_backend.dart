import 'dart:async';
import 'dart:io';

import 'package:kyndrel/core/player/player_backend.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// [PlayerBackend] on libmpv through media_kit.
///
/// Together with `PlayerVideoView`, this is the only code that imports
/// media_kit.
class MediaKitBackend implements PlayerBackend {
  /// [withVideo] is false only for headless engine tests.
  new({bool withVideo = true})
    : player = Player(
        configuration: const PlayerConfiguration(
          // mpv renders subtitles into the frame (libass). This is what makes
          // image subtitles (PGS, VobSub) and the sub-* style options work.
          libass: true,
          logLevel: MPVLogLevel.warn,
          title: 'Kyndrel',
        ),
      ) {
    if (withVideo) {
      videoController = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          // Let mpv pick a hardware decoder, falling back to software. On
          // Android that is MediaCodec (task 6.7).
          hwdec: Platform.isAndroid ? 'mediacodec-copy' : 'auto-safe',
        ),
      );
    }
  }

  final Player player;
  VideoController? videoController;

  NativePlayer? get _native {
    final platform = player.platform;
    return platform is NativePlayer ? platform : null;
  }

  @override
  Stream<bool> get playing => player.stream.playing;
  @override
  Stream<bool> get completed => player.stream.completed;
  @override
  Stream<bool> get buffering => player.stream.buffering;
  @override
  Stream<Duration> get position => player.stream.position;
  @override
  Stream<Duration> get duration => player.stream.duration;
  @override
  Stream<Duration> get buffer => player.stream.buffer;
  @override
  Stream<int?> get width => player.stream.width;
  @override
  Stream<int?> get height => player.stream.height;
  @override
  Stream<double> get volume => player.stream.volume;
  @override
  Stream<double> get rate => player.stream.rate;
  @override
  Stream<String> get error => player.stream.error;
  @override
  Stream<PlayerLogLine> get log => player.stream.log.map(
    (l) => (level: l.level, prefix: l.prefix, text: l.text),
  );
  @override
  Stream<void> get tracksChanged => player.stream.tracks.map((_) {});

  final _observed = <String, StreamController<String>>{};
  final _lastObserved = <String, String>{};

  @override
  Stream<String> observe(String property) {
    final controller = _observed.putIfAbsent(property, () {
      final c = StreamController<String>.broadcast();
      unawaited(
        _native?.observeProperty(property, (value) async {
          _lastObserved[property] = value;
          // mpv can still report a change while the player is closing.
          if (!c.isClosed) c.add(value);
        }),
      );
      return c;
    });
    return Stream.multi((listener) {
      final last = _lastObserved[property];
      if (last != null) listener.add(last);
      final sub = controller.stream.listen(listener.addSync);
      listener.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> open(String source, {required bool play}) =>
      player.open(Media(source), play: play);

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);

  @override
  Future<void> setRate(double rate) => player.setRate(rate);

  @override
  Future<String?> getProperty(String name) async {
    final native = _native;
    if (native == null) return null;
    try {
      return await native.getProperty(name);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> setProperty(String name, String value) =>
      _native?.setProperty(name, value) ?? Future.value();

  @override
  Future<void> command(List<String> args) =>
      _native?.command(args) ?? Future.value();

  @override
  Future<void> dispose() async {
    // The player first: no property callbacks arrive after it is gone.
    await player.dispose();
    for (final c in _observed.values) {
      await c.close();
    }
  }
}
