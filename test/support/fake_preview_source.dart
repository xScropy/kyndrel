import 'package:kyndrel/core/player/preview_thumbnailer.dart';

/// Returns [path] for every request and records the times asked for.
class FakePreviewSource implements PreviewSource {
  new([this.path]);

  String? path;
  final requests = <Duration>[];
  final exactRequests = <Duration>[];

  @override
  Duration stepFor(Duration duration) => const Duration(seconds: 2);

  @override
  Future<String?> frameAt(
    String source,
    Duration at,
    Duration duration, {
    bool exact = false,
    bool background = false,
  }) async {
    (exact ? exactRequests : requests).add(at);
    return path;
  }
}
