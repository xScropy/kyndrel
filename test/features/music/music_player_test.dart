import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/media_session_sync.dart';
import 'package:kyndrel/core/platform/media_session.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/features/music/disc.dart';
import 'package:kyndrel/features/music/now_playing.dart';
import 'package:kyndrel/features/music/waves.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

String _stats(double rmsDb, double peakDb) =>
    '{"lavfi.astats.1.RMS_level":"-90",'
    '"lavfi.astats.Overall.RMS_level":"$rmsDb",'
    '"lavfi.astats.Overall.Peak_level":"$peakDb"}';

class _Session implements MediaSession {
  final updates = <MediaSessionState>[];

  @override
  Stream<MediaCommand> get commands => const Stream.empty();
  @override
  Future<void> update(MediaSessionState state) async => updates.add(state);
  @override
  Future<void> dispose() async {}
}

/// Task 7.6: the music player.
void main() {
  test('loudness from mpv astats, in dB, as 0–1', () {
    final l = AudioLevel.parse(_stats(-12, -3));
    expect(l.rms, closeTo(0.8, 0.001));
    expect(l.peak, closeTo(0.95, 0.001));
    expect(AudioLevel.parse(_stats(-90, -80)).rms, 0);
    expect(AudioLevel.parse('{"x":"nan"}').rms, 0);
    expect(AudioLevel.parse(null).peak, 0);
  });

  Future<AppHarness> song(
    WidgetTester tester, {
    Size size = const Size(392, 800),
    Map<String, Object> prefs = const {},
    _Session? session,
  }) async {
    final h = await AppHarness.create(
      prefs: prefs,
      overrides: [
        if (session != null) mediaSessionProvider.overrideWithValue(session),
      ],
    );
    h.backend.properties['af-metadata/kviz'] = _stats(-10, -2);
    await h.pump(
      tester,
      launch: const LaunchOptions(source: '/m/Music/song.mp3'),
      size: size,
    );
    h.loadSong();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  testWidgets('a song shows the record, its tags and waves', (tester) async {
    final h = await song(tester);
    expect(find.byKey(const Key('music-view')), findsOneWidget);
    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Kyndrel Tests'), findsOneWidget);
    expect(find.text('Test Tones'), findsOneWidget);
    // The level meter filter is on while music plays.
    expect(
      h.backend.commands,
      contains(
        equals(['af', 'add', '@kviz:lavfi=[astats=metadata=1:reset=1]']),
      ),
    );
    // The waves rise with the loudness.
    await tester.pump(const Duration(milliseconds: 500));
    final waves = tester.state<MusicWavesState>(find.byType(MusicWaves));
    expect(waves.level, greaterThan(0.6));
    // The controls stay (nothing to see under them).
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const Key('play-pause')).hitTestable(), findsOneWidget);
  });

  testWidgets('the record turns while playing and eases to a stop', (
    tester,
  ) async {
    final h = await song(tester);
    final disc = tester.state<SpinningDiscState>(find.byType(SpinningDisc));
    final a = disc.angle;
    await tester.pump(const Duration(seconds: 1));
    expect(disc.angle, greaterThan(a));

    h.backend.emitPlaying(value: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final stopped = disc.angle;
    await tester.pump(const Duration(seconds: 2));
    expect(disc.angle, stopped);
  });

  testWidgets('less motion: the record stays still', (tester) async {
    await song(tester, prefs: {'reduceMotion': true});
    final disc = tester.state<SpinningDiscState>(find.byType(SpinningDisc));
    await tester.pump(const Duration(seconds: 2));
    expect(disc.angle, 0);
  });

  testWidgets('no waves when turned off: no meter either', (tester) async {
    final h = await song(tester, prefs: {'musicWaves': false});
    expect(find.byType(MusicWaves), findsNothing);
    expect(
      h.backend.commands.where((c) => c.first == 'af' && c[1] == 'add'),
      isEmpty,
    );
  });

  testWidgets('minimise to browse; the mini player brings it back', (
    tester,
  ) async {
    final h = await song(tester);
    await tester.tap(find.byKey(const Key('music-minimize')));
    await tester.pump();
    expect(find.byKey(const Key('mini-player')), findsOneWidget);
    expect(find.byKey(const Key('library-bar')), findsOneWidget);
    expect(find.text('Night Drive'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-play-pause')));
    await tester.pump();
    expect(h.backend.calls.last, 'pause');

    await tester.tap(find.text('Night Drive'));
    await tester.pump();
    expect(find.byKey(const Key('music-view')), findsOneWidget);
    expect(h.container.read(musicMinimizedProvider), isFalse);
  });

  testWidgets('a video is not music', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/Film.mkv'));
    h.load();
    await tester.pump();
    expect(find.byKey(const Key('music-view')), findsNothing);
    expect(h.container.read(nowPlayingProvider), isNull);
  });

  testWidgets('the notification shows the song, not the file name', (
    tester,
  ) async {
    final session = _Session();
    final h = await song(tester, session: session);
    h.container.read(mediaSessionSyncProvider);
    h.backend.emitPosition(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    h.backend.emitPosition(const Duration(seconds: 7));
    await tester.pump();
    final last = session.updates.last;
    expect(last.title, 'Night Drive');
    expect(last.subtitle, 'Kyndrel Tests · Test Tones');
  });

  for (final (name, size, lang) in [
    ('phone_en', const Size(392, 800), 'en'),
    ('phone_ar', const Size(392, 800), 'ar'),
    ('desktop_en', const Size(1280, 720), 'en'),
  ]) {
    testWidgets('looks right: $name', (tester) async {
      await song(tester, size: size, prefs: {'language': lang});
      // Let the waves rise; then hold still for the picture.
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/music_player_$name.png'),
      );
    });
  }
}
