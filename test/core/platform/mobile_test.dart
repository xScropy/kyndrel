import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:kyndrel/core/logging/crash_monitor.dart';
import 'package:kyndrel/core/platform/mobile_window_service.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

/// Task 6.1: the phone shell.
void main() {
  final phone = <Override>[
    platformCapabilitiesProvider.overrideWithValue(PlatformCapabilities.phone),
  ];

  testWidgets('phones have no window buttons and no in-window PiP', (
    tester,
  ) async {
    final h = await AppHarness.create(overrides: phone);
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    expect(find.byKey(const Key('window-close')), findsNothing);
    expect(find.byKey(const Key('pip')), findsNothing);
    expect(find.byKey(const Key('play-pause')), findsOneWidget);
  });

  testWidgets('desktop keeps them', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();
    expect(find.byKey(const Key('window-close')), findsOneWidget);
    expect(find.byKey(const Key('pip')), findsOneWidget);
  });

  testWidgets('full screen is immersive mode; lifecycle runs the hooks', (
    tester,
  ) async {
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
        }
        return null;
      },
    );
    final w = MobileWindowService();
    addTearDown(w.dispose);
    final events = <String>[];
    w
      ..onHidden(() async => events.add('hidden'))
      ..onShown(() async => events.add('shown'))
      ..onClose(() async => events.add('close'));

    await w.setFullScreen(fullScreen: true);
    expect(w.isFullScreen, isTrue);
    await w.setFullScreen(fullScreen: false);
    expect(modes, ['SystemUiMode.immersiveSticky', 'SystemUiMode.edgeToEdge']);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(events, ['hidden', 'shown']);
    expect(w.isMaximized, isTrue);
  });

  test('a backgrounded session that the system ends is not a crash', () {
    final dir = Directory.systemTemp.createTempSync('kyndrel-mobile');
    addTearDown(() => dir.deleteSync(recursive: true));
    final lock = File(p.join(dir.path, 'session.lock'));
    final m = CrashMonitor(dir, AppLog())..start();
    expect(lock.existsSync(), isTrue);
    m.pause();
    expect(lock.existsSync(), isFalse, reason: 'killed now = clean');
    m.resume();
    expect(lock.existsSync(), isTrue, reason: 'running again');
  });
}
