import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/log_sync.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:kyndrel/core/logging/crash_monitor.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/features/logs/log_viewer_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';

Directory _tempDir() {
  final d = Directory.systemTemp.createTempSync('kyndrel-logs');
  addTearDown(() => d.deleteSync(recursive: true));
  return d;
}

void main() {
  group('AppLog', () {
    test('keeps the newest records in memory', () {
      final log = AppLog(capacity: 3);
      for (var i = 0; i < 5; i++) {
        log.info('app', 'line $i');
      }
      expect(log.records.map((r) => r.message), ['line 2', 'line 3', 'line 4']);
      expect(log.tail(2), allOf(contains('line 3'), contains('line 4')));
      expect(log.tail(2), isNot(contains('line 2')));
    });

    test('appends to kyndrel.log and rotates to kyndrel.1.log', () {
      final dir = _tempDir();
      final log = AppLog(directory: dir, maxFileBytes: 300)
        ..warn('mpv/ffmpeg', 'first')
        ..error('app', 'é ünïcödé');
      expect(
        log.file!.readAsStringSync(),
        contains('WARN  [mpv/ffmpeg] first'),
      );
      for (var i = 0; i < 20; i++) {
        log.info('app', 'filler line number $i');
      }
      expect(log.previousFile!.existsSync(), isTrue);
      expect(log.file!.lengthSync(), lessThan(600));
      expect(
        log.previousFile!.readAsStringSync() + log.file!.readAsStringSync(),
        contains('filler line number 19'),
      );
    });
  });

  group('CrashMonitor', () {
    test('a clean session leaves nothing to report', () {
      final dir = _tempDir();
      final m = CrashMonitor(dir, AppLog(directory: dir))..start();
      expect(m.previous, isNull);
      m.cleanExit();
      final next = CrashMonitor(dir, AppLog(directory: dir))..start();
      expect(next.previous, isNull);
    });

    test('a session that never closed is an unexpected exit', () {
      final dir = _tempDir();
      final log = AppLog(directory: dir);
      CrashMonitor(dir, log).start();
      log.info('app', 'last thing before the crash');
      // No cleanExit: the process died.
      final next = CrashMonitor(dir, AppLog(directory: dir))..start();
      expect(next.previous?.unexpectedExit, isTrue);
      expect(next.previous?.log, contains('last thing before the crash'));
    });

    test('an uncaught error is kept for the next start', () {
      final dir = _tempDir();
      final log = AppLog(directory: dir);
      CrashMonitor(dir, log)
        ..start()
        ..recordError(StateError('boom'), StackTrace.current)
        ..recordError(StateError('second'), null)
        ..cleanExit();
      expect(log.records.last.message, contains('second'));
      final next = CrashMonitor(dir, AppLog(directory: dir))..start();
      expect(next.previous?.unexpectedExit, isFalse);
      expect(next.previous?.error, startsWith('Bad state: boom'));
      // Read once: the start after that is clean.
      next.cleanExit();
      expect(
        (CrashMonitor(dir, AppLog(directory: dir))..start()).previous,
        isNull,
      );
    });
  });

  test('the GitHub issue link is pre-filled and bounded', () {
    final url = crashIssueUrl(
      repository: 'xScropy/kyndrel',
      version: '1.0.0',
      os: 'linux test',
      report: CrashReport(
        unexpectedExit: true,
        error: 'Bad state: boom\n#0 main',
        log: List.generate(500, (i) => 'log line $i').join('\n'),
      ),
    );
    expect(url.host, 'github.com');
    expect(url.path, '/xScropy/kyndrel/issues/new');
    expect(url.queryParameters['title'], 'Crash: Bad state: boom');
    final body = url.queryParameters['body']!;
    expect(body, contains('**Kyndrel** 1.0.0 · **OS** linux test'));
    expect(body, contains('closed unexpectedly'));
    expect(body, contains('log line 499'));
    expect(body, isNot(contains('log line 0\n')));
    expect(body.length, lessThan(6200));
  });

  testWidgets('mpv log lines reach the app log', (tester) async {
    final h = await AppHarness.create();
    await h.pump(tester);
    h.container.read(logSyncProvider);
    h.backend.emitLog('error', 'ffmpeg', 'Invalid data found');
    await tester.pump();
    final last = h.container.read(appLogProvider).records.last;
    expect(last.level, LogLevel.error);
    expect(last.source, 'mpv/ffmpeg');
    expect(last.message, 'Invalid data found');
  });

  group('crash prompt', () {
    CrashMonitor crashed() {
      final dir = _tempDir();
      File(p.join(dir.path, 'session.lock')).writeAsStringSync('1');
      return CrashMonitor(dir, AppLog())..start();
    }

    testWidgets('offers a pre-filled report after a crash', (tester) async {
      final opened = <String>[];
      final h = await AppHarness.create(
        overrides: [
          crashMonitorProvider.overrideWithValue(crashed()),
          externalOpenerProvider.overrideWithValue((t) async => opened.add(t)),
        ],
      );
      await h.pump(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('crash-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('crash-report')));
      await tester.pumpAndSettle();
      expect(opened.single, startsWith('https://github.com/'));
      expect(opened.single, contains('issues/new'));
    });

    testWidgets('stays quiet when reports are turned off', (tester) async {
      final h = await AppHarness.create(
        prefs: {'offerCrashReports': false},
        overrides: [crashMonitorProvider.overrideWithValue(crashed())],
      );
      await h.pump(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('crash-dialog')), findsNothing);
    });
  });

  testWidgets('log viewer filters by level', (tester) async {
    final log = AppLog()
      ..debug('app', 'chatty detail')
      ..info('app', 'opened film.mkv')
      ..error('mpv/ffmpeg', 'decoder failed');
    final h = await AppHarness.create(
      overrides: [appLogProvider.overrideWithValue(log)],
    );
    await h.pumpWidget(
      tester,
      const LogViewerPage(),
      size: const Size(900, 500),
    );
    expect(find.textContaining('opened film.mkv'), findsOneWidget);
    expect(find.textContaining('decoder failed'), findsOneWidget);
    expect(find.textContaining('chatty detail'), findsNothing);

    await tester.tap(find.byKey(const Key('log-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('error and up').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('opened film.mkv'), findsNothing);
    expect(find.textContaining('decoder failed'), findsOneWidget);
  });
}
