import 'package:flutter/foundation.dart';

/// Picture presets (task 4.6). Applied through mpv's GPU renderer; the
/// software fallback on some Linux setups ignores them.
enum VideoPreset {
  /// Fast scaling, lowest GPU load.
  fast('Fast'),

  /// mpv's defaults.
  standard('Standard'),

  /// EWA Lanczos scaling, linear-light downscaling and deband.
  highQuality('High quality'),

  /// High quality plus a light sharpening shader.
  sharpen('High quality + sharpen');

  new(this.label);
  final String label;

  Map<String, String> get options => switch (this) {
    // Harbor's "Performance": also no dithering, faster decoding, no
    // frame interpolation and no HDR peak measuring (task 9.4).
    VideoPreset.fast => const {
      'scale': 'bilinear',
      'cscale': 'bilinear',
      'dscale': 'bilinear',
      'correct-downscaling': 'no',
      'sigmoid-upscaling': 'no',
      'linear-downscaling': 'no',
      'dither': 'no',
      'dither-depth': 'no',
      'vd-lavc-fast': 'yes',
      'interpolation': 'no',
      'hdr-compute-peak': 'no',
    },
    VideoPreset.standard => const {
      'scale': 'lanczos',
      'cscale': 'lanczos',
      'dscale': 'hermite',
      'correct-downscaling': 'yes',
      'sigmoid-upscaling': 'yes',
      'linear-downscaling': 'yes',
      'dither': 'fruit',
      'dither-depth': 'no',
      'vd-lavc-fast': 'no',
      'hdr-compute-peak': 'auto',
    },
    // Harbor's "Quality".
    VideoPreset.highQuality || VideoPreset.sharpen => const {
      'scale': 'ewa_lanczossharp',
      'cscale': 'ewa_lanczossharp',
      'dscale': 'mitchell',
      'correct-downscaling': 'yes',
      'sigmoid-upscaling': 'yes',
      'linear-downscaling': 'yes',
      'dither': 'fruit',
      'dither-depth': 'auto',
      'vd-lavc-fast': 'no',
      'hdr-compute-peak': 'yes',
    },
  };

  bool get usesShader => this == VideoPreset.sharpen;
}

/// mpv `hwdec` choices (task 4.6).
const hwdecChoices = {
  'auto-safe': 'Automatic',
  'no': 'Off (software)',
  'd3d11va': 'D3D11 (Windows)',
  'nvdec': 'NVIDIA NVDEC',
  'vaapi': 'VA-API (Linux)',
  'videotoolbox': 'VideoToolbox (macOS)',
  'mediacodec-copy': 'MediaCodec (Android)',
};

/// mpv `tone-mapping` choices for HDR on SDR screens (task 4.6).
const toneMappingChoices = {
  'auto': 'Automatic',
  'bt.2390': 'BT.2390',
  'hable': 'Hable (filmic)',
  'mobius': 'Möbius',
  'reinhard': 'Reinhard',
  'clip': 'Clip',
};

/// Loudness normalization (task 4.7).
enum Normalization {
  off('Off', null),

  /// EBU R128 to −16 LUFS: consistent loudness between files.
  loudnorm('Loudness (EBU R128)', 'loudnorm=I=-16:TP=-1.5:LRA=11'),

  /// Evens out quiet dialogue and loud effects within a file: Harbor's
  /// stronger settings (longer window, more gain, a 4× cap) and a limiter
  /// so the loud parts never clip (task 9.4).
  dynamic(
    'Dynamic (night mode)',
    'dynaudnorm=f=500:g=31:p=0.9:m=4:b=1,alimiter=limit=0.97',
  );

  new(this.label, this.filter);
  final String label;

  /// lavfi graph, or null when off.
  final String? filter;
}

/// 10-band graphic equalizer (task 4.7).
abstract final class Equalizer {
  static const frequencies = [
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];
  static const maxGain = 12.0;

  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'Treble boost': [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
    'Voice': [-4, -3, -1, 1, 3, 4, 4, 3, 1, -1],
    'Rock': [4, 3, 1, -1, -2, -1, 1, 3, 4, 4],
    'Classical': [3, 2, 1, 0, 0, 0, 0, 1, 2, 3],
    'Cinema': [4, 3, 1, 0, -1, 0, 1, 2, 2, 1],
  };

  static bool isFlat(List<double> gains) => gains.every((g) => g == 0);

  /// The lavfi graph for [gains] (one peaking filter per band), or null if
  /// flat.
  static String? filter(List<double> gains) {
    if (isFlat(gains)) return null;
    return [
      for (var i = 0; i < frequencies.length && i < gains.length; i++)
        if (gains[i] != 0) _band(frequencies[i], gains[i]),
    ].join(',');
  }

  static String _band(int f, double g) =>
      'equalizer=f=$f:t=o:w=1:g=${g.toStringAsFixed(1)}';

  static String? presetName(List<double> gains) {
    for (final e in presets.entries) {
      if (listEquals(e.value, gains)) return e.key;
    }
    return null;
  }
}
