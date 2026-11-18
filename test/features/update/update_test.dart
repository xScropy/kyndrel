import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/features/update/update_banner.dart';
import 'package:kyndrel/features/update/update_checker.dart';
import 'package:kyndrel/features/update/update_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

const _assets = [
  'Kyndrel-1.2.0-windows-x64-setup.exe',
  'Kyndrel-1.2.0-macos-universal.dmg',
  'Kyndrel-1.2.0-x86_64.AppImage',
  'kyndrel_1.2.0_amd64.deb',
];

String _release(String tag) => jsonEncode({
  'tag_name': tag,
  'html_url': 'https://github.com/xScropy/kyndrel/releases/tag/$tag',
  'body': 'Notes',
  'assets': [
    for (final a in _assets)
      {'name': a, 'browser_download_url': 'https://dl.example/$a'},
  ],
});

MockClient _github(String tag, {int status = 200}) => MockClient((req) async {
  if (req.url.host == 'api.github.com') {
    expect(req.url.path, '/repos/xScropy/kyndrel/releases/latest');
    return http.Response(status == 200 ? _release(tag) : '', status);
  }
  // The installer download.
  return http.Response.bytes(List.filled(4096, 7), 200);
});

UpdateChecker _checker(
  String tag, {
  String current = '1.1.0',
  UpdatePackage package = UpdatePackage.linuxDeb,
  int status = 200,
}) => UpdateChecker(
  repository: 'xScropy/kyndrel',
  currentVersion: current,
  client: _github(tag, status: status),
  package: package,
);

void main() {
  group('versions', () {
    AppVersionNumber v(String s) => AppVersionNumber.tryParse(s)!;

    test('parse with or without v, compare numerically', () {
      expect(v('v1.10.0') > v('1.9.3'), isTrue);
      expect(v('1.2') == v('1.2.0'), isTrue);
      expect(AppVersionNumber.tryParse('nightly'), isNull);
    });

    test('a pre-release comes before its release', () {
      expect(v('1.0.0') > v('1.0.0-beta.2'), isTrue);
      expect(v('1.0.0-beta.2') > v('1.0.0-beta.1'), isTrue);
      expect(v('1.0.0-rc.1') > v('0.9.9'), isTrue);
    });
  });

  group('checker', () {
    test("a newer release picks this platform's installer", () async {
      for (final (package, file) in [
        (UpdatePackage.windowsInstaller, _assets[0]),
        (UpdatePackage.macDmg, _assets[1]),
        (UpdatePackage.linuxAppImage, _assets[2]),
        (UpdatePackage.linuxDeb, _assets[3]),
      ]) {
        final info = await _checker('v1.2.0', package: package).check();
        expect(info!.version.toString(), '1.2.0');
        expect(info.downloadUrl.toString(), 'https://dl.example/$file');
        expect(info.pageUrl.path, endsWith('/releases/tag/v1.2.0'));
        expect(info.notes, 'Notes');
      }
    });

    test('same or older version: no update', () async {
      expect(await _checker('v1.1.0').check(), isNull);
      expect(await _checker('v1.0.5').check(), isNull);
    });

    test('no release published yet (404): no update', () async {
      expect(await _checker('x', status: 404).check(), isNull);
    });

    test('server errors are reported', () async {
      expect(
        _checker('x', status: 502).check(),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('download writes the file and reports progress', () async {
      final dir = Directory.systemTemp.createTempSync('kyndrel-upd');
      addTearDown(() => dir.deleteSync(recursive: true));
      final seen = <double>[];
      final f = await _checker('v1.2.0').download(
        Uri.parse('https://dl.example/x.exe'),
        File('${dir.path}/x.exe'),
        onProgress: seen.add,
      );
      expect(f.lengthSync(), 4096);
      expect(seen.last, 1);
    });
  });

  group('controller', () {
    ProviderContainer container({
      required String tag,
      bool inPlace = false,
      List<String>? opened,
      List<String>? ran,
    }) {
      final c = ProviderContainer(
        overrides: [
          updateCheckerProvider.overrideWithValue(
            _checker(
              tag,
              package: inPlace
                  ? UpdatePackage.windowsInstaller
                  : UpdatePackage.linuxDeb,
            ),
          ),
          updateInstallsInPlaceProvider.overrideWithValue(inPlace),
          externalOpenerProvider.overrideWithValue((t) async => opened?.add(t)),
          installerRunnerProvider.overrideWithValue((p) async => ran?.add(p)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('automatic check is quiet when up to date', () async {
      final c = container(tag: 'v0.0.1');
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider), isA<UpdateIdle>());
      await c.read(updateProvider.notifier).check(manual: true);
      expect(c.read(updateProvider), isA<UpdateUpToDate>());
    });

    test('macOS/Linux: install opens the download in the browser', () async {
      final opened = <String>[];
      final c = container(tag: 'v9.0.0', opened: opened);
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider), isA<UpdateAvailable>());
      await c.read(updateProvider.notifier).install();
      expect(opened, ['https://dl.example/kyndrel_1.2.0_amd64.deb']);
    });

    test('Windows: install downloads the setup and runs it', () async {
      final ran = <String>[];
      final c = container(tag: 'v9.0.0', inPlace: true, ran: ran);
      final states = <UpdateStatus>[];
      c.listen(updateProvider, (_, s) => states.add(s));
      await c.read(updateProvider.notifier).check();
      await c.read(updateProvider.notifier).install();
      expect(states.whereType<UpdateDownloading>(), isNotEmpty);
      expect(ran.single, endsWith('Kyndrel-1.2.0-windows-x64-setup.exe'));
      expect(File(ran.single).lengthSync(), 4096);
    });
  });

  group('banner', () {
    testWidgets('appears after the start delay when checks are on', (
      tester,
    ) async {
      final opened = <String>[];
      final h = await AppHarness.create(
        prefs: {'checkForUpdates': true},
        overrides: [
          updateCheckerProvider.overrideWithValue(_checker('v9.0.0')),
          updateInstallsInPlaceProvider.overrideWithValue(false),
          externalOpenerProvider.overrideWithValue((t) async => opened.add(t)),
        ],
      );
      await h.pump(tester, launch: const LaunchOptions(source: '/v/f.mkv'));
      expect(find.byKey(const Key('update-banner')), findsNothing);

      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump(UpdateBanner.startDelay);
      // The mock client answers on the real event loop.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.text('Kyndrel 9.0.0 is available'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.byKey(const Key('update-notes')));
      await tester.pump();
      expect(opened.single, endsWith('/releases/tag/v9.0.0'));

      await tester.tap(find.byKey(const Key('update-later')));
      await tester.pump();
      expect(find.byKey(const Key('update-banner')), findsNothing);
    });

    testWidgets('no check at all when the setting is off', (tester) async {
      var asked = false;
      final h = await AppHarness.create(
        overrides: [
          updateCheckerProvider.overrideWithValue(
            UpdateChecker(
              repository: 'xScropy/kyndrel',
              currentVersion: '1.0.0',
              client: MockClient((_) async {
                asked = true;
                return http.Response('', 404);
              }),
            ),
          ),
        ],
      );
      await h.pump(tester);
      await tester.pump(UpdateBanner.startDelay * 2);
      expect(asked, isFalse);
    });
  });
}
