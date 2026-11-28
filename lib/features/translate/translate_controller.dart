import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/subtitles/subtitle_encoding.dart';
import 'package:kyndrel/core/subtitles/subtitle_file.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/features/translate/translators.dart';
import 'package:path/path.dart' as p;

/// Gets the cues of a subtitle track.
abstract interface class SubtitleExtractor {
  /// Cues of [track] in [source]. Throws [TranslationException] with a
  /// user-facing message when it can't.
  Future<List<Cue>> cues(
    String source,
    MediaTrack track,
    List<MediaTrack> allSubtitles,
  );
}

/// External files are parsed directly; embedded text tracks are extracted
/// with FFmpeg when it's installed.
class DefaultSubtitleExtractor implements SubtitleExtractor {
  const new({this.ffmpeg = 'ffmpeg'});

  final String ffmpeg;

  @override
  Future<List<Cue>> cues(
    String source,
    MediaTrack track,
    List<MediaTrack> allSubtitles,
  ) async {
    final file = track.externalFilename;
    if (track.isExternal && file != null) {
      final f = File(file);
      if (!f.existsSync()) {
        throw const TranslationException('The subtitle file is gone.');
      }
      final bytes = await f.readAsBytes();
      return parseSubtitles(
        // Any encoding (task 9.5).
        SubtitleEncoding.decode(bytes).text,
        extension: p.extension(file),
      );
    }
    // The n-th embedded subtitle stream, in the same order as mpv's ids.
    final embedded = allSubtitles.where((t) => !t.isExternal).toList();
    final index = embedded.indexWhere((t) => t.id == track.id);
    if (index < 0 || source.contains('://')) {
      throw const TranslationException(
        'Only subtitle files and subtitles inside local files can be '
        'translated.',
      );
    }
    final ProcessResult r;
    try {
      r = await Process.run(ffmpeg, [
        '-nostdin', '-loglevel', 'error', '-i', source, //
        '-map', '0:s:$index', '-f', 'srt', '-',
      ], stdoutEncoding: utf8);
    } on ProcessException {
      // Phones can't run FFmpeg (task 6.6).
      throw TranslationException(
        Platform.isAndroid
            ? 'Only subtitle files can be translated on this device: load '
                  'one from the subtitles panel.'
            : 'Install FFmpeg to translate subtitles inside the video, or '
                  'load a subtitle file.',
      );
    }
    if (r.exitCode != 0) {
      throw TranslationException(
        "Couldn't read the subtitle track: ${r.stderr}",
      );
    }
    return parseSubtitles(r.stdout as String, extension: 'srt');
  }
}

enum TranslateStatus { idle, reading, translating, done, failed }

@immutable
class TranslateState {
  const new({
    this.status = TranslateStatus.idle,
    this.done = 0,
    this.total = 0,
    this.message,
    this.target,
    this.output,
  });

  final TranslateStatus status;
  final int done;
  final int total;
  final String? message;
  final String? target;

  /// The translated SRT once finished.
  final String? output;

  bool get busy =>
      status == TranslateStatus.reading ||
      status == TranslateStatus.translating;
}

final subtitleExtractorProvider = Provider<SubtitleExtractor>(
  (ref) => const DefaultSubtitleExtractor(),
);

/// The configured translator, or null when its key is missing.
final translatorProvider = Provider<Translator?>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s.translateProvider) {
    'deepl' when s.deeplApiKey.isNotEmpty => DeepLTranslator(s.deeplApiKey),
    'google' when s.googleTranslateApiKey.isNotEmpty => GoogleTranslator(
      s.googleTranslateApiKey,
    ),
    'claude' when s.anthropicApiKey.isNotEmpty => ClaudeTranslator(
      s.anthropicApiKey,
    ),
    _ => null,
  };
});

/// Translates the active subtitle track and shows the result as the second
/// subtitle line (task 4.2). Results are cached per file, track, language
/// and provider.
class TranslateController extends Notifier<TranslateState> {
  static const attempts = 3;
  bool _cancelled = false;

  @override
  TranslateState build() => const TranslateState();

  void cancel() {
    _cancelled = true;
    if (state.busy) {
      state = const TranslateState(message: 'Cancelled.');
    }
  }

  Future<void> start(String target) async {
    if (state.busy) return;
    _cancelled = false;
    final service = ref.read(playerServiceProvider);
    final source = service.state.source;
    final tracks = service.tracks;
    final track = tracks.selectedSubtitle;
    if (source == null || track == null) {
      _fail('Turn on a subtitle track first.');
      return;
    }
    if (track.isImageSubtitle) {
      _fail("Image subtitles (PGS, VobSub) can't be translated.");
      return;
    }
    final translator = ref.read(translatorProvider);
    if (translator == null) {
      _fail('Add an API key for the translation service in Settings.');
      return;
    }

    final key = fnv1a64(
      '$source|${track.externalFilename ?? 'embedded:${track.id}'}',
    );
    final out = p.join(
      ref.read(appCacheDirProvider).path,
      'translations',
      '$key-$target-${translator.id}.srt',
    );

    try {
      if (!File(out).existsSync()) {
        state = TranslateState(status: TranslateStatus.reading, target: target);
        final cues = await ref
            .read(subtitleExtractorProvider)
            .cues(source, track, tracks.subtitles);
        if (cues.isEmpty) {
          throw const TranslationException('The track is empty.');
        }
        final translated = await _translateAll(translator, cues, target);
        if (translated == null) return; // Cancelled.
        File(out)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(writeSrt(translated));
      }
      await _show(out, target);
    } on TranslationException catch (e) {
      _fail(e.message);
    } on FileSystemException catch (e) {
      _fail("Couldn't save the translation: ${e.message}");
    } on TimeoutException {
      _fail("The translated subtitles didn't load. Try again.");
    }
  }

  Future<List<Cue>?> _translateAll(
    Translator t,
    List<Cue> cues,
    String target,
  ) async {
    final result = <Cue>[];
    state = TranslateState(
      status: TranslateStatus.translating,
      total: cues.length,
      target: target,
    );
    for (var i = 0; i < cues.length; i += t.batchSize) {
      if (_cancelled) return null;
      final batch = cues.sublist(i, (i + t.batchSize).clamp(0, cues.length));
      final lines = await _withRetry(
        () => t.translate([for (final c in batch) c.text], target: target),
      );
      if (_cancelled) return null;
      if (lines.length != batch.length) {
        throw const TranslationException(
          'The translation came back incomplete. Try again.',
        );
      }
      for (var j = 0; j < batch.length; j++) {
        result.add(batch[j].withText(lines[j]));
      }
      state = TranslateState(
        status: TranslateStatus.translating,
        done: result.length,
        total: cues.length,
        target: target,
      );
    }
    return result;
  }

  Future<List<String>> _withRetry(Future<List<String>> Function() f) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await f();
      } on TranslationException catch (e) {
        final last = attempt >= attempts;
        // Bad keys and quotas won't fix themselves.
        if (last || (e.retryAfter == null && attempt > 1)) rethrow;
        if (e.message.contains('key') || e.message.contains('quota')) rethrow;
        await Future<void>.delayed(e.retryAfter ?? const Duration(seconds: 1));
      } on Exception catch (e) {
        if (attempt >= attempts) {
          throw TranslationException('Translation failed: $e');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _show(String path, String target) async {
    final service = ref.read(playerServiceProvider);
    final existing = service.tracks.subtitles
        .where((t) => t.externalFilename == path)
        .firstOrNull;
    var id = existing?.id;
    if (id == null) {
      final added = service.trackStates
          .map(
            (s) => s.subtitles
                .where((t) => t.externalFilename == path)
                .firstOrNull,
          )
          .firstWhere((t) => t != null)
          .timeout(const Duration(seconds: 5));
      await service.addSubtitle(
        path,
        select: false,
        title: 'Translated · ${languageName(target)}',
      );
      id = (await added)!.id;
    }
    await service.selectSecondarySubtitle(id);
    state = TranslateState(
      status: TranslateStatus.done,
      target: target,
      output: path,
      message: 'Showing ${languageName(target)} as the second line.',
    );
  }

  void _fail(String message) =>
      state = TranslateState(status: TranslateStatus.failed, message: message);
}

final translateProvider = NotifierProvider<TranslateController, TranslateState>(
  TranslateController.new,
);
