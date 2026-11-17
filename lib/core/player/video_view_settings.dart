import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';

/// Picture fit modes from the fit icon (task 2.12).
enum VideoFit {
  /// Whole picture, letterboxed (original aspect).
  fit('Fit'),

  /// Fill the window, cropping the edges.
  fill('Fill'),

  /// Fill the window, distorting the aspect.
  stretch('Stretch'),

  /// Force 16:9 (mpv `video-aspect-override`).
  ratio16x9('16:9'),

  /// Force 4:3 (mpv `video-aspect-override`).
  ratio4x3('4:3'),

  /// 1:1 pixels, no scaling.
  original('Original');

  new(this.label);
  final String label;

  /// Value for mpv `video-aspect-override`, or null for the file's own.
  String? get aspectOverride => switch (this) {
    VideoFit.ratio16x9 => '16:9',
    VideoFit.ratio4x3 => '4:3',
    _ => null,
  };
}

@immutable
class VideoViewSettings {
  const new({this.fit = VideoFit.fit, this.zoom = 1, this.rotation = 0});

  final VideoFit fit;

  /// 1 = no zoom; up to [maxZoom].
  final double zoom;

  /// Clockwise degrees: 0, 90, 180, 270.
  final int rotation;

  static const double minZoom = 1;
  static const double maxZoom = 4;
  static const double zoomStep = 0.25;

  VideoViewSettings copyWith({VideoFit? fit, double? zoom, int? rotation}) =>
      VideoViewSettings(
        fit: fit ?? this.fit,
        zoom: zoom ?? this.zoom,
        rotation: rotation ?? this.rotation,
      );

  @override
  bool operator ==(Object other) =>
      other is VideoViewSettings &&
      other.fit == fit &&
      other.zoom == zoom &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(fit, zoom, rotation);
}

final videoViewProvider =
    NotifierProvider<VideoViewNotifier, VideoViewSettings>(
      VideoViewNotifier.new,
    );

/// Per-session picture settings. Aspect overrides and rotation go to mpv;
/// fit, fill, stretch and zoom are applied to the Flutter texture.
class VideoViewNotifier extends Notifier<VideoViewSettings> {
  @override
  VideoViewSettings build() => const VideoViewSettings();

  Future<void> setFit(VideoFit fit) async {
    state = state.copyWith(fit: fit);
    await ref.read(playerServiceProvider).setAspectOverride(fit.aspectOverride);
  }

  void setZoom(double zoom) {
    state = state.copyWith(
      zoom: zoom.clamp(VideoViewSettings.minZoom, VideoViewSettings.maxZoom),
    );
  }

  void zoomBy(double delta) => setZoom(state.zoom + delta);

  Future<void> rotateClockwise() => setRotation(state.rotation + 90);

  Future<void> setRotation(int degrees) async {
    state = state.copyWith(rotation: degrees % 360);
    await ref.read(playerServiceProvider).setRotation(state.rotation);
  }

  Future<void> reset() async {
    await setFit(VideoFit.fit);
    setZoom(1);
    await setRotation(0);
  }
}
