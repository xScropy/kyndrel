import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_player_backend.dart';

void main() {
  group('parseEpisode', () {
    final cases = <String, (String, int, int, int?)?>{
      'Show.Name.S01E02.720p.mkv': ('show name', 1, 2, null),
      'show name s1e2.mp4': ('show name', 1, 2, null),
      'Show_Name_S01.E02.mkv': ('show name', 1, 2, null),
      'Show.Name.S02E10E11.mkv': ('show name', 2, 10, 11),
      'Show.Name.S02E10-E11.mkv': ('show name', 2, 10, 11),
      'Show Name 1x02 Title.avi': ('show name', 1, 2, null),
      'Show.Name.2019.S03E04.mkv': ('show name', 3, 4, null),
      'Show Name (2019) - S03E04.mkv': ('show name', 3, 4, null),
      'Show Name Season 2 Episode 7.mp4': ('show name', 2, 7, null),
      '[Group] Anime Show - 05 [1080p].mkv': ('anime show', 1, 5, null),
      'Anime Show - 12v2.mkv': ('anime show', 1, 12, null),
      r'C:\TV\Show.S01E01.mkv': ('show', 1, 1, null),
      'Movie Title - 2019.mkv': null,
      'The.Matrix.1999.1080p.mkv': null,
      'holiday.mp4': null,
    };
    for (final e in cases.entries) {
      test(e.key, () {
        final r = parseEpisode(e.key);
        expect(
          r == null ? null : (r.show, r.season, r.episode, r.lastEpisode),
          e.value,
        );
      });
    }

    test('code', () {
      expect(parseEpisode('X.S01E02.mkv')!.code, 'S01E02');
      expect(parseEpisode('X.S01E02E03.mkv')!.code, 'S01E02-E03');
    });
  });

  test('sortEpisodes orders by season and episode, then other files', () {
    expect(
      sortEpisodes([
        'Show.S02E01.mkv',
        'Extras.mkv',
        'Show.S01E10.mkv',
        'Show.S01E02.mkv',
      ]),
      ['Show.S01E02.mkv', 'Show.S01E10.mkv', 'Show.S02E01.mkv', 'Extras.mkv'],
    );
  });

  test('episodesFrom keeps the same show, from the current episode', () {
    expect(
      episodesFrom('Show.S01E02.mkv', [
        'Show.S01E01.mkv',
        'Show.S01E02.mkv',
        'Show.S01E03.mkv',
        'Other.S01E04.mkv',
      ]),
      ['Show.S01E02.mkv', 'Show.S01E03.mkv'],
    );
    expect(episodesFrom('film.mkv', ['film.mkv']), isEmpty);
  });

  group('auto-play next episode', () {
    late Directory dir;
    late FakePlayerBackend backend;
    late ProviderContainer container;

    Future<void> setUpWith({required bool enabled}) async {
      dir = Directory.systemTemp.createTempSync('kyndrel_ep');
      for (final n in [
        'Show.S01E01.mkv',
        'Show.S01E02.mkv',
        'Show.S01E03.mkv',
        'Other.S01E01.mkv',
      ]) {
        File(p.join(dir.path, n)).writeAsStringSync('x');
      }
      SharedPreferences.setMockInitialValues({'autoPlayNextEpisode': enabled});
      backend = FakePlayerBackend();
      container = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(PlayerService(backend)),
          settingsRepositoryProvider.overrideWithValue(
            await SettingsRepository.create(),
          ),
        ],
      )..listen(playlistProvider, (_, _) {});
    }

    tearDown(() {
      container.dispose();
      dir.deleteSync(recursive: true);
    });

    test('queues the rest of the season', () async {
      await setUpWith(enabled: true);
      await container
          .read(playlistProvider.notifier)
          .open(p.join(dir.path, 'Show.S01E02.mkv'));
      expect(container.read(playlistProvider).items.map(p.basename), [
        'Show.S01E02.mkv',
        'Show.S01E03.mkv',
      ]);
    });

    test('off: just the one file', () async {
      await setUpWith(enabled: false);
      await container
          .read(playlistProvider.notifier)
          .open(p.join(dir.path, 'Show.S01E02.mkv'));
      expect(container.read(playlistProvider).items, hasLength(1));
    });
  });
}
