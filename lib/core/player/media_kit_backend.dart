import 'package:kyndrel/core/player/player_backend.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// [PlayerBackend] on libmpv through media_kit.
///
/// Together with `PlayerVideoView`, this is the only code that imports
/// media_kit.
class MediaKitBackend implements PlayerBackend {
  new() : player = Player() {
    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        // Let mpv pick a hardware decoder, falling back to software.
        hwdec: 'auto-safe',
      ),
    );
  }

  final Player player;
  late final VideoController videoController;

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
  Stream<String> get error => player.stream.error;

  @override
  Future<void> open(String source, {required bool play}) =>
      player.open(Media(source), play: play);

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<String?> getProperty(String name) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return null;
    try {
      return await platform.getProperty(name);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() => player.dispose();
}
