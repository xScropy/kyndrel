import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/mpv_options.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:path/path.dart' as p;

/// Copies the bundled shader to a real file mpv can read.
Future<String?> _shaderFile(Directory cache) async {
  try {
    final data = await rootBundle.load('assets/shaders/sharpen.glsl');
    final f = File(p.join(cache.path, 'shaders', 'sharpen.glsl'));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  } on Object {
    return null;
  }
}

/// Applies saved settings to the engine at start-up and whenever they
/// change: volume, limiter, subtitles, picture and audio effects.
final engineSyncProvider = Provider<void>((ref) {
  final service = ref.watch(playerServiceProvider);
  final initial = ref.read(settingsProvider);
  String? shader;
  Future<void> applyVideo(AppSettings s) async {
    if (s.videoPreset.usesShader) {
      shader ??= await _shaderFile(ref.read(appCacheDirProvider));
    }
    await service.applyVideoPreset(s.videoPreset, shaderPath: shader);
  }

  unawaited(() async {
    await service.setLimiterEnabled(enabled: initial.limiterEnabled);
    await service.setVolume(initial.volume);
    await service.setAutoLoadSubtitles(enabled: initial.autoLoadSubtitles);
    await service.applySubtitleStyle(initial.subtitleStyle);
    await service.setHardwareDecoding(initial.hwdec);
    await service.setDeband(enabled: initial.deband);
    await service.setToneMapping(initial.toneMapping);
    await applyVideo(initial);
    await service.setEqualizer(initial.equalizer);
    await service.setNormalization(initial.normalization);
    // Last, so the user's own options win.
    await service.applyOptions(parseMpvOptions(initial.mpvOptions).options);
  }());

  ref
    ..listen(settingsProvider.select((s) => s.limiterEnabled), (_, v) {
      unawaited(service.setLimiterEnabled(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.autoLoadSubtitles), (_, v) {
      unawaited(service.setAutoLoadSubtitles(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.subtitleStyle), (_, v) {
      unawaited(service.applySubtitleStyle(v));
    })
    ..listen(settingsProvider.select((s) => s.videoPreset), (_, _) {
      unawaited(applyVideo(ref.read(settingsProvider)));
    })
    ..listen(settingsProvider.select((s) => s.hwdec), (_, v) {
      unawaited(service.setHardwareDecoding(v));
    })
    ..listen(settingsProvider.select((s) => s.deband), (_, v) {
      unawaited(service.setDeband(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.toneMapping), (_, v) {
      unawaited(service.setToneMapping(v));
    })
    ..listen(settingsProvider.select((s) => s.equalizer), (_, v) {
      unawaited(service.setEqualizer(v));
    })
    ..listen(settingsProvider.select((s) => s.normalization), (_, v) {
      unawaited(service.setNormalization(v));
    })
    ..listen(settingsProvider.select((s) => s.mpvOptions), (_, v) {
      unawaited(service.applyOptions(parseMpvOptions(v).options));
    });
});
