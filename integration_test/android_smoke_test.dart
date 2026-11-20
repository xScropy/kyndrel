// Emulator smoke test (task 6.8): the real app, libmpv and Android.
//   KYNDREL_SMOKE_URL=http://10.0.2.2:8000/The.Test.Film.2019.1080p.mkv
//   flutter test integration_test/android_smoke_test.dart \
//     --dart-define=KYNDREL_SMOKE_URL=$KYNDREL_SMOKE_URL
// CI serves test_media/generated/ from the runner (10.0.2.2 is the host).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kyndrel/app/player_page.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/main.dart' as app;
import 'package:material_ui/material_ui.dart';

const _url = String.fromEnvironment(
  'KYNDREL_SMOKE_URL',
  defaultValue: 'http://10.0.2.2:8000/The.Test.Film.2019.1080p.mkv',
);

/// A song with cover art and tags (task 7.6), next to the film.
final String _song = _url.replaceFirst(RegExp(r'[^/]+$'), 'song.mp3');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'open, play, swipe, preview, subtitles',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      // The app installs its crash handler; errors must reach the test
      // instead, so a failure says what went wrong.
      final onError = FlutterError.onError;
      await app.main([_url]);
      FlutterError.onError = onError;

      // Plays: the elapsed time moves within 60 s.
      String elapsed() {
        final f = find.byKey(const Key('seek-elapsed'));
        if (f.evaluate().isEmpty) return '';
        return tester.widget<Text>(f).data ?? '';
      }

      var playing = false;
      for (var i = 0; i < 120 && !playing; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        final t = elapsed();
        playing = t.isNotEmpty && t != '0:00';
      }
      expect(playing, isTrue, reason: 'elapsed time never moved');

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final centre = size.center(Offset.zero);

      // Volume swipe on the right half shows the level indicator.
      final right = Offset(size.width * 0.75, centre.dy);
      final finger = await tester.startGesture(right);
      for (var i = 1; i <= 10; i++) {
        await finger.moveTo(right.translate(0, -12.0 * i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('level-osd')), findsOneWidget);
      await finger.up();
      await tester.pump(const Duration(seconds: 1));

      // Horizontal swipe shows the scene preview.
      final left = Offset(size.width * 0.3, centre.dy);
      final seek = await tester.startGesture(left);
      for (var i = 1; i <= 10; i++) {
        await seek.moveTo(left.translate(15.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('swipe-seek-preview')), findsOneWidget);
      await seek.up();
      await tester.pump(const Duration(seconds: 1));

      // The subtitles panel opens (and fits). A tap on the video toggles the
      // controls, so try with them shown either way.
      final panel = find.byKey(const Key('subtitle-panel'));
      for (var i = 0; i < 2 && panel.evaluate().isEmpty; i++) {
        await tester.tapAt(centre);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(
          find.byKey(const Key('subtitles-button')),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(seconds: 1));
      }
      expect(panel, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Music: the record view with the song's tags (task 7.6).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerPage)),
      );
      await container.read(playlistProvider.notifier).open(_song);
      var music = false;
      for (var i = 0; i < 60 && !music; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        music = find.byKey(const Key('music-view')).evaluate().isNotEmpty;
      }
      expect(music, isTrue, reason: 'the song never showed the music view');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Night Drive'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
