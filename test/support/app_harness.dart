import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/app/app.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/player_page.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/metadata/media_identity.dart';
import 'package:kyndrel/core/net/skip_segments.dart';
import 'package:kyndrel/core/platform/power_state.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/library_previews.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/free_sources.dart';
import 'package:kyndrel/features/subtitles/subtitle_search_controller.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_media_library.dart';
import 'fake_player_backend.dart';
import 'fake_power_state.dart';
import 'fake_preview_source.dart';
import 'fake_storyboard_source.dart';
import 'fake_window_service.dart';
import 'test_database.dart';

/// Everything a full-page test needs, with fakes for the engine, the window
/// and storage.
class AppHarness {
  new _(
    this.backend,
    this.service,
    this.window,
    this.db,
    this.settings, [
    this.extraOverrides = const [],
  ]);

  final FakePlayerBackend backend;
  final PlayerService service;
  final FakeWindowService window;
  final KyndrelDatabase db;

  /// Library previews (task 8.4).
  final FakeStoryboardSource libraryStoryboards = FakeStoryboardSource();
  final FakePowerState power = FakePowerState();
  final SettingsRepository settings;
  final FakePreviewSource previews = FakePreviewSource();
  final FakeStoryboardSource storyboards = FakeStoryboardSource();
  final FakeMediaScanner scanner = FakeMediaScanner();
  final FakeMediaProber prober = FakeMediaProber();

  /// A cache folder of its own (storyboards are written there).
  final Directory cacheDir = Directory.systemTemp.createTempSync('kyndrel_c');
  late ProviderContainer container;

  /// Extra provider overrides for one test (e.g. a fake update server).
  final List<Override> extraOverrides;

  /// Answers every request the online lookups make (Phase 9: titles,
  /// skip segments, keyless subtitle sources). Not found by default; a test
  /// sets it to serve answers.
  Future<http.Response> Function(http.Request request) net = (_) async =>
      http.Response('', 404);

  late final http.Client _net = MockClient((r) => net(r));

  /// Builds the harness inside the test body (fake-async zone).
  static Future<AppHarness> create({
    Map<String, Object> prefs = const {},
    List<Override> overrides = const [],
  }) async {
    // No GitHub update check unless a test asks for one (task 5.6).
    SharedPreferences.setMockInitialValues({
      'checkForUpdates': false,
      ...prefs,
    });
    final backend = FakePlayerBackend();
    final h = AppHarness._(
      backend,
      PlayerService(backend),
      FakeWindowService(),
      testDatabase(),
      await SettingsRepository.create(),
      overrides,
    );
    addTearDown(h.service.dispose);
    addTearDown(() => h.cacheDir.deleteSync(recursive: true));
    addTearDown(h.db.close);
    return h;
  }

  List<Override> get overrides => [
    playerServiceProvider.overrideWithValue(service),
    windowServiceProvider.overrideWithValue(window),
    settingsRepositoryProvider.overrideWithValue(settings),
    databaseProvider.overrideWithValue(db),
    appCacheDirProvider.overrideWithValue(cacheDir),
    previewSourceProvider.overrideWithValue(previews),
    storyboardSourceProvider.overrideWithValue(storyboards),
    libraryStoryboardSourceProvider.overrideWithValue(libraryStoryboards),
    powerStateProvider.overrideWithValue(power),
    mediaScannerProvider.overrideWithValue(scanner),
    mediaProberProvider.overrideWithValue(prober),
    mediaIdentifierProvider.overrideWithValue(MediaIdentifier(client: _net)),
    skipSegmentsClientProvider.overrideWithValue(
      SkipSegmentsClient(client: _net),
    ),
    freeSubtitleSourcesProvider.overrideWithValue(
      FreeSubtitleSources(
        cacheDir: Directory('${cacheDir.path}/subtitles'),
        client: _net,
      ),
    ),
    ...extraOverrides,
  ];

  Future<void> pump(
    WidgetTester tester, {
    LaunchOptions launch = const LaunchOptions(),
    Size size = const Size(1280, 720),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: KyndrelApp(launch: launch),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    await tester.pump();
  }

  /// Pumps [child] alone (with the same overrides) for widget tests and
  /// goldens.
  Future<void> pumpWidget(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(800, 200),
    Locale? locale,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: KyndrelTheme.dark(),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.delegates,
          home: Scaffold(body: child),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(child)));
    await tester.pump();
  }

  /// Simulates mpv finishing loading the opened file, with tracks.
  /// A song with cover art and tags is playing (task 7.6).
  void loadSong({
    String title = 'Night Drive',
    String artist = 'Kyndrel Tests',
    String album = 'Test Tones',
    bool playing = true,
  }) {
    backend
      ..emitDuration(const Duration(minutes: 3, seconds: 30))
      ..emitPlaying(value: playing)
      ..emitProperty('metadata/by-key/title', title)
      ..emitProperty('metadata/by-key/artist', artist)
      ..emitProperty('metadata/by-key/album', album)
      ..emitTracks([
        {'id': '1', 'type': 'audio', 'codec': 'mp3', 'default': 'yes'},
        {'id': '1', 'type': 'video', 'codec': 'mjpeg', 'albumart': 'yes'},
      ])
      ..emitProperty('aid', '1');
  }

  void load({
    Duration duration = const Duration(minutes: 60),
    int width = 1920,
    int height = 800,
    bool playing = true,
  }) {
    backend
      ..emitDuration(duration)
      ..emitSize(width, height)
      ..emitPlaying(value: playing)
      ..emitTracks([
        {'id': '1', 'type': 'video', 'codec': 'h264'},
        {
          'id': '1',
          'type': 'audio',
          'lang': 'eng',
          'title': 'Stereo',
          'demux-channel-count': '2',
          'default': 'yes',
        },
        {'id': '2', 'type': 'audio', 'lang': 'ara'},
        {'id': '1', 'type': 'sub', 'lang': 'eng', 'codec': 'subrip'},
        {'id': '2', 'type': 'sub', 'lang': 'fre', 'codec': 'hdmv_pgs_subtitle'},
        {
          'id': '3',
          'type': 'sub',
          'lang': 'ar',
          'codec': 'subrip',
          'external': 'yes',
          'external-filename': '/v/Film.ar.srt',
        },
      ])
      ..emitProperty('aid', '1')
      ..emitProperty('sid', '3');
  }
}
