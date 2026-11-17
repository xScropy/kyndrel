import 'package:flutter/foundation.dart';
import 'package:kyndrel/core/player/remote_target.dart';

/// What to play on the device.
@immutable
class CastMedia {
  const new({
    required this.url,
    required this.contentType,
    required this.title,
    this.startAt = Duration.zero,
    this.subtitleUrl,
  });

  final Uri url;
  final String contentType;
  final String title;
  final Duration startAt;
  final Uri? subtitleUrl;
}

/// A connected device that can load media and be controlled.
abstract interface class CastSession implements RemoteTarget {
  Future<void> loadMedia(CastMedia media);
}
