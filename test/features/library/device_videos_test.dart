import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/device_media.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/features/library/device_videos.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_media.dart';

void main() {
  final library = [
    video('Holiday.mp4', 'Camera'),
    video('Clip.mp4', 'Camera', id: 2),
    video('Show.S01E01.mkv', 'Download', id: 3),
  ];

  testWidgets('asks for access, then lists folders and plays a folder', (
    tester,
  ) async {
    final media = FakeDeviceMedia(library: library);
    final h = await AppHarness.create(
      overrides: [deviceMediaProvider.overrideWithValue(media)],
    );
    await h.pumpWidget(
      tester,
      const SingleChildScrollView(child: DeviceVideosSection()),
      size: const Size(400, 700),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('device-videos-allow')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Camera · 2'), findsOneWidget);
    expect(find.text('Download · 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('device-folder-Camera')));
    await tester.pump();
    expect(find.text('Show.S01E01.mkv'), findsNothing);
    await tester.tap(find.text('Clip.mp4'));
    await tester.pump();

    final q = h.container.read(playlistProvider);
    expect(q.items, [
      'content://media/external/video/media/1',
      'content://media/external/video/media/2',
    ]);
    expect(q.current, 1);
    // The opaque URI gets its real name in titles and history.
    expect(parseMediaTitle(q.items[1]).title, 'Clip');
  });

  testWidgets('a refused permission says so and offers the button again', (
    tester,
  ) async {
    final h = await AppHarness.create(
      overrides: [
        deviceMediaProvider.overrideWithValue(
          FakeDeviceMedia(library: library, grant: false),
        ),
      ],
    );
    await h.pumpWidget(tester, const DeviceVideosSection());
    await tester.pump();
    await tester.tap(find.byKey(const Key('device-videos-allow')));
    await tester.pump();
    expect(find.textContaining('needs permission'), findsOneWidget);
    expect(find.byKey(const Key('device-videos-allow')), findsOneWidget);
  });

  testWidgets('nothing at all on desktop', (tester) async {
    final h = await AppHarness.create();
    await h.pumpWidget(tester, const DeviceVideosSection());
    expect(find.byKey(const Key('device-videos-allow')), findsNothing);
  });

  testWidgets('"Open with" from Android: {uri, name} maps', (tester) async {
    final h = await AppHarness.create();
    await h.pumpWidget(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => OpenActions.openFromSystem(ref, [
            {'uri': 'content://x/1', 'name': 'The.Film.2020.mkv'},
          ]),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(h.backend.calls.last, startsWith('open(content://x/1'));
    final t = parseMediaTitle('content://x/1');
    expect((t.title, t.year), ('The Film', 2020));
  });
}
