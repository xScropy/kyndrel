@Tags(['engine'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/media_kit_backend.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Task 7.1 against the real libmpv: a chosen subtitle track produces text.
///   scripts/make_test_media.sh && flutter test -t engine --run-skipped
void main() {
  final media = p.absolute('test_media/generated');
  final fonts = p.absolute('assets/fonts');
  final film = p.join(media, 'The.Test.Film.2019.1080p.mkv');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    if (!File(film).existsSync()) fail('Run scripts/make_test_media.sh first.');
  });

  late PlayerService service;

  setUp(() async {
    service = PlayerService(
      MediaKitBackend(withVideo: false, subtitleFontsDir: fonts),
    );
    await service.backend.setProperty('ao', 'null');
    await service.backend.setProperty('vo', 'null');
    await service.backend.setProperty('vid', 'auto');
    await service.setAutoLoadSubtitles(enabled: true);
  });

  tearDown(() => service.dispose().timeout(const Duration(seconds: 20)));

  Future<String?> prop(String name) => service.backend.getProperty(name);

  Future<void> eventually(
    Future<bool> Function() check, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await check()) {
      if (DateTime.now().isAfter(end)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(String path) async {
    await service.open(path);
    await eventually(() async => service.state.isPlaying);
    await eventually(() async => service.tracks.subtitles.length >= 2);
  }

  MediaTrack embeddedSrt() => service.tracks.subtitles.firstWhere(
    (s) => s.codec == 'subrip' && !s.isExternal,
  );

  /// The text mpv would draw now, after seeking into the cue.
  Future<String> textAt(Duration at) async {
    await service.seek(at);
    String? text;
    await eventually(() async {
      text = await prop('sub-text');
      return text != null && text!.isNotEmpty;
    });
    return text!;
  }

  test('the fonts folder reaches mpv', () async {
    expect(await prop('sub-fonts-dir'), fonts);
  });

  test('an embedded text track shows its text', () async {
    await open(film);
    expect(await service.selectSubtitle(embeddedSrt().id), isTrue);
    expect(
      await textAt(const Duration(seconds: 2)),
      contains('embedded English'),
    );
  });

  test('the auto-loaded external file shows its text', () async {
    await open(film);
    final ar = service.tracks.subtitles.firstWhere((s) => s.isExternal);
    expect(await service.selectSubtitle(ar.id), isTrue);
    expect(await textAt(const Duration(seconds: 2)), contains('External'));
  });

  test('a file added while playing shows its text', () async {
    await open(film);
    final before = service.tracks.subtitles.length;
    await service.addSubtitle(p.join(media, 'extra.srt'));
    await eventually(() async => service.tracks.subtitles.length > before);
    expect(await textAt(const Duration(seconds: 2)), contains('sub-add'));
  });

  test('the secondary track moves to the main line', () async {
    await open(film);
    final srt = embeddedSrt();
    await service.selectSecondarySubtitle(srt.id);
    await eventually(() async => service.tracks.secondarySubtitleId == srt.id);
    expect(await service.selectSubtitle(srt.id), isTrue);
    expect(await prop('sid'), '${srt.id}');
    expect(await prop('secondary-sid'), 'no');
    expect(await textAt(const Duration(seconds: 2)), contains('English'));
  });

  test('hidden subtitles come back when a track is chosen', () async {
    await open(film);
    await service.backend.setProperty('sub-visibility', 'no');
    await service.selectSubtitle(embeddedSrt().id);
    expect(await prop('sub-visibility'), 'yes');
  });

  test('choosing again after another file opened', () async {
    // A file without subtitles first.
    await service.open(p.join(media, 'clip.mp4'));
    await eventually(() async => service.state.isPlaying);
    await open(film);
    expect(await service.selectSubtitle(embeddedSrt().id), isTrue);
    expect(await textAt(const Duration(seconds: 3)), contains('English'));
    expect(service.state.status, isNot(PlaybackStatus.error));
  });
}
