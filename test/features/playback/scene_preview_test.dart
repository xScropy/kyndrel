import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/player/android_frame_source.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/preview_prewarm.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';
import '../../support/fake_player_backend.dart';
import '../../support/fake_preview_source.dart';

/// Task 6.4: the scene preview while seeking on a phone.
void main() {
  Future<AppHarness> phone(WidgetTester tester) async {
    final h = await AppHarness.create(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.phone,
        ),
      ],
    );
    h.previews.path = '/tmp/kyndrel-frame.jpg';
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    h.backend.emitPosition(const Duration(minutes: 10));
    await tester.pump();
    return h;
  }

  testWidgets('swiping sideways shows the scene, time and frame', (
    tester,
  ) async {
    final h = await phone(tester);
    final finger = await tester.startGesture(const Offset(400, 400));
    for (var i = 1; i <= 8; i++) {
      await finger.moveTo(Offset(400 + 40.0 * i, 400));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('swipe-seek-preview')), findsOneWidget);
    expect(find.byKey(const Key('swipe-seek-frame')), findsOneWidget);
    // 320 px of 1280 = a quarter of 3 min = 45 s on from 10:00.
    expect(find.text('10:45'), findsOneWidget);
    expect(h.previews.requests.last, const Duration(minutes: 10, seconds: 45));

    await finger.up();
    await tester.pump();
    expect(find.byKey(const Key('swipe-seek-preview')), findsNothing);
  });

  testWidgets('touch drag on the seek bar: big frame, gone on release', (
    tester,
  ) async {
    await phone(tester);
    final bar = tester.getRect(find.byKey(const Key('seek-bar')));
    final finger = await tester.startGesture(
      bar.centerLeft + const Offset(40, 0),
    );
    for (var i = 1; i <= 6; i++) {
      await finger.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 80));
    }
    final frame = find.byKey(const Key('seek-preview'));
    expect(frame, findsOneWidget);
    // About 40 % of the bar's width, capped at 360.
    expect(tester.getSize(frame).width, greaterThan(300));

    await finger.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('seek-preview')), findsNothing);
  });

  group('AndroidFrameSource', () {
    late Directory dir;
    late List<Map<Object?, Object?>> calls;
    const channel = MethodChannel('kyndrel/frames.test');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      dir = Directory.systemTemp.createTempSync('kyndrel-frames');
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = (call.arguments as Map).cast<Object?, Object?>();
            calls.add(args);
            File(args['path']! as String)
              ..createSync(recursive: true)
              ..writeAsBytesSync([1, 2, 3]);
            return true;
          });
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('asks Android for the frame, then serves it from the cache', () async {
      final s = AndroidFrameSource(cacheDir: dir, channel: channel);
      const source = 'content://media/external/video/media/7';
      final path = await s.frameAt(
        source,
        const Duration(seconds: 125),
        const Duration(hours: 1),
      );
      expect(path, isNotNull);
      expect(p.isWithin(p.join(dir.path, 'previews'), path!), isTrue);
      // Snapped to the step (18 s for an hour): 125 → 108.
      expect(calls.single['ms'], 108000);
      expect(calls.single['width'], AndroidFrameSource.width);

      await s.frameAt(
        source,
        const Duration(seconds: 120),
        const Duration(hours: 1),
      );
      expect(calls, hasLength(1), reason: 'same step: cached');
    });

    test('network streams get no preview', () async {
      final s = AndroidFrameSource(cacheDir: dir, channel: channel);
      expect(
        await s.frameAt(
          'https://x.example/a.m3u8',
          const Duration(seconds: 5),
          const Duration(minutes: 5),
        ),
        isNull,
      );
      expect(calls, isEmpty);
    });
  });

  test('pre-warm renders chapter starts and 19 points after loading', () {
    fakeAsync((async) {
      final backend = FakePlayerBackend();
      final service = PlayerService(backend);
      final previews = FakePreviewSource('/x.jpg');
      final c = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(service),
          previewSourceProvider.overrideWithValue(previews),
        ],
      )..read(previewPrewarmProvider);
      unawaited(service.open('/v/film.mkv'));
      async.flushMicrotasks();
      backend.emitDuration(const Duration(minutes: 20));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 4));
      expect(previews.requests, hasLength(19));
      expect(previews.requests.first, const Duration(minutes: 1));
      c.dispose();
      unawaited(service.dispose());
      async.flushMicrotasks();
    });
  });
}
