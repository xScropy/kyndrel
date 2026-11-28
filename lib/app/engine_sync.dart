import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/mpv_options.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
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
    await service.setVolume(
      initial.volume.clamp(0, initial.volumeBoostMax).toDouble(),
    );
    await service.setAutoLoadSubtitles(enabled: initial.autoLoadSubtitles);
    await service.applySubtitleStyle(initial.subtitleStyle);
    await service.setHardwareDecoding(_decoder(initial.hwdec));
    await service.setDeband(enabled: initial.deband);
    await service.setToneMapping(initial.toneMapping);
    await applyVideo(initial);
    await service.setEqualizer(initial.equalizer);
    await service.setNormalization(initial.normalization);
    if (initial.audioPassthrough) {
      await service.setAudioPassthrough(enabled: true);
    }
    if (initial.audioDevice != 'auto') {
      await service.setAudioDevice(initial.audioDevice);
    }
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
      unawaited(service.setHardwareDecoding(_decoder(v)));
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
    ..listen(settingsProvider.select((s) => s.audioPassthrough), (_, v) {
      unawaited(service.setAudioPassthrough(enabled: v));
    })
    ..listen(settingsProvider.select((s) => s.volumeBoostMax), (_, max) {
      // A lower limit brings a louder volume down to it.
      if (service.state.volume > max) unawaited(service.setVolume(max));
    })
    ..listen(settingsProvider.select((s) => s.audioDevice), (_, v) {
      unawaited(service.setAudioDevice(v));
    })
    ..listen(settingsProvider.select((s) => s.mpvOptions), (_, v) {
      unawaited(service.applyOptions(parseMpvOptions(v).options));
    });
});

/// Says so when the sound device didn't open, instead of playing silently:
/// the usual causes are a device that was unplugged or taken by another
/// app, the wrong output device, or passthrough to laptop speakers.
final audioProblemNoticeProvider = Provider<void>((ref) {
  final sub = ref.watch(playerServiceProvider).audioProblems.listen((_) {
    final s = ref.read(settingsProvider);
    ref
        .read(osdProvider.notifier)
        .show(
          s.audioPassthrough
              ? audioProblemPassthroughText
              : s.audioDevice == 'auto'
              ? audioProblemText
              : audioProblemDeviceText,
        );
  });
  ref.onDispose(() => unawaited(sub.cancel()));
});

const audioProblemText =
    'No sound: the audio device did not open. Retrying… '
    'Pick one in Settings › Audio › Output device.';
const audioProblemDeviceText =
    'No sound from the chosen output device. Try Automatic in '
    'Settings › Audio › Output device.';
const audioProblemPassthroughText =
    'No sound: audio passthrough needs an AV receiver. Turn it off in '
    'Settings › Audio for speakers and headphones.';

/// "Automatic" on Android is MediaCodec with a copy back (task 6.7): it is
/// what works with media_kit's texture output, and mpv still falls back to
/// software for formats the phone can't decode.
String _decoder(String setting) =>
    setting == 'auto-safe' && Platform.isAndroid ? 'mediacodec-copy' : setting;
