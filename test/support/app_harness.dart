import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/player_page.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_player_backend.dart';
import 'fake_window_service.dart';

/// Everything a full-page test needs, with fakes for the engine, the window
/// and storage.
class AppHarness {
  new _(this.backend, this.service, this.window, this.db, this.settings);

  final FakePlayerBackend backend;
  final PlayerService service;
  final FakeWindowService window;
  final KyndrelDatabase db;
  final SettingsRepository settings;
  late ProviderContainer container;

  /// Builds the harness inside the test body (fake-async zone).
  static Future<AppHarness> create({
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final backend = FakePlayerBackend();
    final h = AppHarness._(
      backend,
      PlayerService(backend),
      FakeWindowService(),
      KyndrelDatabase(NativeDatabase.memory()),
      await SettingsRepository.create(),
    );
    addTearDown(h.service.dispose);
    addTearDown(h.db.close);
    return h;
  }

  List<Override> get overrides => [
    playerServiceProvider.overrideWithValue(service),
    windowServiceProvider.overrideWithValue(window),
    settingsRepositoryProvider.overrideWithValue(settings),
    databaseProvider.overrideWithValue(db),
    appCacheDirProvider.overrideWithValue(Directory.systemTemp),
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
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: KyndrelTheme.dark(),
          home: PlayerPage(launch: launch),
        ),
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
          home: Scaffold(body: child),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(child)));
    await tester.pump();
  }

  /// Simulates mpv finishing loading the opened file, with tracks.
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
