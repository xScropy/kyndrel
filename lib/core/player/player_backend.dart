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
  Stream<String> get error;

  Future<void> open(String source, {required bool play});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Reads an mpv property as a string, or null when unavailable.
  Future<String?> getProperty(String name);

  Future<void> dispose();
}
