import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

ScannedFile _song(
  String path, {
  String? title,
  String? artist,
  String? album,
  int? track,
}) => ScannedFile(
  uri: path,
  name: path.split('/').last,
  folderPath: path.substring(0, path.lastIndexOf('/')),
  kind: MediaKind.audio,
  size: 4000000,
  modified: DateTime(2026),
  added: DateTime(2026, 10),
  duration: const Duration(minutes: 3, seconds: 30),
  title: title,
  artist: artist,
  album: album,
  trackNo: track,
);

/// Task 7.5: the music library, separate from the videos.
void main() {
  Future<AppHarness> music(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
    Map<String, Object> prefs = const {},
  }) async {
    final h = await AppHarness.create(prefs: prefs);
    h.scanner.files = [
      _song(
        '/m/Music/Night/02 b.mp3',
        title: 'Blue Hour',
        artist: 'Kyn',
        album: 'Night',
        track: 2,
      ),
      _song(
        '/m/Music/Night/01 a.mp3',
        title: 'Arrival',
        artist: 'Kyn',
        album: 'Night',
        track: 1,
      ),
      _song(
        '/m/Music/Day/sun.flac',
        title: 'Sun',
        artist: 'Dawn',
        album: 'Day',
      ),
      _song('/m/Downloads/voice memo.m4a'),
    ];
    await h.pump(tester, size: size);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.music);
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('songs by title; a tap plays the list from there', (
    tester,
  ) async {
    final h = await music(tester);
    expect(find.text('Music'), findsWidgets);
    for (final t in ['Arrival', 'Blue Hour', 'Sun', 'voice memo']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Kyn · Night'), findsNWidgets(2));
    await tester.tap(find.text('Sun'));
    await tester.pump();
    final queue = h.container.read(playlistProvider);
    expect(queue.items, [
      '/m/Music/Night/01 a.mp3',
      '/m/Music/Night/02 b.mp3',
      '/m/Music/Day/sun.flac',
      '/m/Downloads/voice memo.m4a',
    ]);
    expect(queue.current, 2);
  });

  testWidgets('albums play in track order; untagged songs are Unknown', (
    tester,
  ) async {
    final h = await music(tester);
    await tester.tap(find.byKey(const Key('music-albums')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-Night')), findsOneWidget);
    expect(find.byKey(const Key('group-Unknown album')), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-Night')));
    await tester.pumpAndSettle();
    expect(find.text('2 songs'), findsOneWidget);
    await tester.tap(find.byKey(const Key('music-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-Day')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-Night')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-play')));
    await tester.pump();
    expect(h.container.read(playlistProvider).items, [
      '/m/Music/Night/01 a.mp3',
      '/m/Music/Night/02 b.mp3',
    ]);
  });

  testWidgets('artists, folders, search and shuffle all', (tester) async {
    final h = await music(tester);
    await tester.tap(find.byKey(const Key('music-artists')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-Kyn')), findsOneWidget);
    expect(find.byKey(const Key('group-Unknown artist')), findsOneWidget);
    await tester.tap(find.byKey(const Key('music-folders')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('music-search')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('music-search-field')), 'dawn');
    await tester.pumpAndSettle();
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Arrival'), findsNothing);

    await tester.tap(find.byKey(const Key('music-shuffle')));
    await tester.pump();
    expect(h.container.read(playlistProvider).items, hasLength(4));
  });

  for (final (name, size, lang) in [
    ('desktop_en', const Size(1280, 720), 'en'),
    ('phone_en', const Size(392, 800), 'en'),
    ('phone_ar', const Size(392, 800), 'ar'),
  ]) {
    testWidgets('looks right: $name', (tester) async {
      await music(tester, size: size, prefs: {'language': lang});
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/music_songs_$name.png'),
      );
      await tester.tap(find.byKey(const Key('music-albums')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/music_albums_$name.png'),
      );
    });
  }
}
