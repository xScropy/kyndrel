import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/utils/media_format.dart';
import 'package:kyndrel/features/library/library_shell.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

ScannedFile _video(
  String path, {
  int minutes = 90,
  int width = 1920,
  int height = 1080,
  int size = 1500000000,
  DateTime? added,
}) => ScannedFile(
  uri: path,
  name: path.split('/').last,
  folderPath: path.substring(0, path.lastIndexOf('/')),
  kind: MediaKind.video,
  size: size,
  modified: DateTime(2026),
  added: added ?? DateTime(2026, 10),
  duration: Duration(minutes: minutes),
  width: width,
  height: height,
);

/// Task 7.4: the video library.
void main() {
  group('labels', () {
    test('resolutions, wide films included', () {
      expect(resolutionLabel(3840, 2160), '4K');
      expect(resolutionLabel(1920, 800), '1080p');
      expect(resolutionLabel(1280, 720), '720p');
      expect(resolutionLabel(720, 1280), '720p');
      expect(resolutionLabel(640, 480), '480p');
      expect(resolutionLabel(null, 480), isNull);
    });

    test('sizes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(700 * 1024 * 1024), '700 MB');
      expect(formatBytes(1500000000), '1.4 GB');
    });
  });

  Future<AppHarness> library(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
    Map<String, Object> prefs = const {},
  }) async {
    final h = await AppHarness.create(prefs: prefs);
    h.scanner.files = [
      _video('/m/Films/The Heist.mkv', added: clock.now()),
      _video('/m/Films/Arrival.mp4', minutes: 116, size: 900000000),
      _video('/m/Clips/cat.mp4', minutes: 1, width: 1280, height: 720),
    ];
    await h.pump(tester, size: size);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.videos);
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('folders, then the videos in one, with their details', (
    tester,
  ) async {
    await library(tester);
    expect(find.byKey(const Key('folder-Films')), findsOneWidget);
    expect(find.byKey(const Key('folder-Clips')), findsOneWidget);
    expect(find.textContaining('2 videos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folder-Films')));
    await tester.pumpAndSettle();
    expect(find.text('Films'), findsOneWidget);
    expect(find.byKey(const Key('video-The Heist.mkv')), findsOneWidget);
    expect(find.text('1:30:00'), findsOneWidget);
    expect(find.textContaining('1080p'), findsNWidgets(2));
    // Added today and never played.
    expect(find.text('NEW'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folder-Films')), findsOneWidget);
  });

  testWidgets('playing a video queues the rest of its folder', (tester) async {
    final h = await library(tester);
    await tester.tap(find.byKey(const Key('folder-Films')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-Arrival.mp4')));
    await tester.pump();
    final queue = h.container.read(playlistProvider);
    expect(queue.items, ['/m/Films/The Heist.mkv', '/m/Films/Arrival.mp4']);
    expect(queue.current, 1);
    expect(h.backend.calls.last, startsWith('open(/m/Films/Arrival.mp4'));
  });

  testWidgets('search across folders, and sort by name', (tester) async {
    await library(tester);
    await tester.tap(find.byKey(const Key('library-search')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('library-search-field')), 'ar');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video-Arrival.mp4')), findsOneWidget);
    expect(find.byKey(const Key('video-cat.mp4')), findsNothing);

    await tester.tap(find.byKey(const Key('library-search')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('library-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sort-name')));
    await tester.pumpAndSettle();
    final names = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('library-videos')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .where((s) => s != null && s.contains('.m'))
        .toList();
    expect(names, ['Arrival.mp4', 'cat.mp4', 'The Heist.mkv']);
  });

  testWidgets('details sheet: everything known, and Add to queue', (
    tester,
  ) async {
    final h = await library(tester);
    await tester.tap(find.byKey(const Key('folder-Clips')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-cat.mp4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video-details')), findsOneWidget);
    expect(find.text('1280 × 720 (720p)'), findsOneWidget);
    expect(find.text('/m/Clips'), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-enqueue')));
    // An empty queue starts playing (a spinner: never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.container.read(playlistProvider).items, ['/m/Clips/cat.mp4']);
  });

  testWidgets('no access: a button to ask again', (tester) async {
    final h = await AppHarness.create();
    h.scanner.grant = false;
    await h.pump(tester);
    h.container
        .read(librarySectionProvider.notifier)
        .show(LibrarySection.videos);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-allow')), findsOneWidget);
    h.scanner
      ..grant = true
      ..files = [_video('/m/Films/a.mkv')];
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folder-Films')), findsOneWidget);
  });

  for (final (name, size, lang) in [
    ('desktop_en', const Size(1280, 720), 'en'),
    ('phone_en', const Size(392, 800), 'en'),
    ('phone_ar', const Size(392, 800), 'ar'),
  ]) {
    // Pinned to the day the goldens were made, so dates on screen match.
    testWidgets('looks right: $name', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 20, 12)), () async {
        await library(tester, size: size, prefs: {'language': lang});
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/video_library_$name.png'),
        );
        await tester.tap(find.byKey(const Key('folder-Films')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/video_folder_$name.png'),
        );
      });
    });
  }
}
