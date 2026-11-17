import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/features/playback/player_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late PlayerService service;

  Future<void> pumpScreen(WidgetTester tester, {String? source}) async {
    // Built inside the test so its streams run in the test's fake-async zone.
    backend = FakePlayerBackend();
    service = PlayerService(backend);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: KyndrelTheme.dark(),
          home: PlayerScreen(initialSource: source),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('idle shows the open prompt and opens what is typed', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('OPEN MEDIA'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('open-source-field')),
      '/videos/film.mkv',
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(backend.calls, ['open(/videos/film.mkv, play: true)']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('initial source opens on start, spinner until loaded', (
    tester,
  ) async {
    await pumpScreen(tester, source: 'a.mp4');
    expect(backend.calls, ['open(a.mp4, play: true)']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    backend
      ..emitDuration(const Duration(minutes: 1))
      ..emitPlaying(value: true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('OPEN MEDIA'), findsNothing);
  });

  testWidgets('error shows the message and a way to open something else', (
    tester,
  ) async {
    await pumpScreen(tester, source: 'broken.avi');
    backend.emitError('Failed to recognize file format.');
    await tester.pump();

    expect(find.text("Can't play this file"), findsOneWidget);
    expect(find.text('Failed to recognize file format.'), findsOneWidget);
    expect(find.text('OPEN MEDIA'), findsOneWidget);
  });
}
