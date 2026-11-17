/// One line of mpv's log.
typedef PlayerLogLine = ({String level, String prefix, String text});

/// The raw engine underneath `PlayerService`.
///
/// Production uses `MediaKitBackend` (libmpv). Tests use a fake, so all of
/// `PlayerService`'s logic runs without a native library.
abstract interface class PlayerBackend {
  Stream<bool> get playing;
  Stream<bool> get completed;
  Stream<bool> get buffering;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<int?> get width;
  Stream<int?> get height;
  Stream<double> get volume;
  Stream<double> get rate;
  Stream<String> get error;
  Stream<PlayerLogLine> get log;

  /// Fires whenever mpv's `track-list` changes.
  Stream<void> get tracksChanged;

  /// Values of an mpv property as strings, starting with the current one.
  Stream<String> observe(String property);

  Future<void> open(String source, {required bool play});
  Future<void> stop();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);

  /// Reads an mpv property as a string, or null when unavailable.
  Future<String?> getProperty(String name);
  Future<void> setProperty(String name, String value);
  Future<void> command(List<String> args);

  Future<void> dispose();
}
