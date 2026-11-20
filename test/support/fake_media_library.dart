import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/media_prober.dart';

/// A device with the given files (task 7.3).
class FakeMediaScanner implements MediaScanner {
  List<ScannedFile> files = [];
  bool grant = true;

  @override
  Future<bool> requestAccess() async => grant;

  @override
  Future<List<ScannedFile>> scan() async => grant ? files : const [];
}

/// Knows nothing more than the scan; no thumbnails.
class FakeMediaProber implements MediaProber {
  String? thumbnailPath;

  @override
  Future<ProbedDetails?> probe(String uri) async => null;

  @override
  Future<String?> thumbnail(
    String uri,
    MediaKind kind, {
    Duration? duration,
    bool hasCover = true,
  }) async => thumbnailPath;
}
