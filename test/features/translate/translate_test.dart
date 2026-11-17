// Request bodies are inspected as decoded JSON.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/subtitles/subtitle_file.dart';
import 'package:kyndrel/features/translate/translate_controller.dart';
import 'package:kyndrel/features/translate/translators.dart';

import '../../support/fake_player_backend.dart';

const _srt = '''
1
00:00:01,000 --> 00:00:02,500
Hello <i>there</i>

2
00:00:03,000 --> 00:00:04,000
Two
lines
''';

void main() {
  group('parsers', () {
    test('SRT strips tags and keeps line breaks', () {
      expect(parseSubtitles(_srt), const [
        Cue(Duration(seconds: 1), Duration(milliseconds: 2500), 'Hello there'),
        Cue(Duration(seconds: 3), Duration(seconds: 4), 'Two\nlines'),
      ]);
    });

    test('WebVTT', () {
      const vtt =
          'WEBVTT\n\n00:01.000 --> 00:02.000 align:start\nHi\n\n'
          'note\n01:00:00.500 --> 01:00:01.000\n<v Bob>Yo\n';
      final c = parseSubtitles(vtt, extension: '.vtt');
      expect(c.map((e) => e.text), ['Hi', 'Yo']);
      expect(c[1].start, const Duration(hours: 1, milliseconds: 500));
    });

    test(r'ASS dialogue with commas, tags and \N', () {
      const ass =
          '[Script Info]\nTitle: x\n\n[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text\n'
          r'Dialogue: 0,0:00:05.10,0:00:06.00,Default,,0,0,0,,{\i1}Wait,'
          r' what?\NNo.'
          '\nDialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,First\n';
      final c = parseSubtitles(ass, extension: 'ass');
      expect(c.map((e) => e.text), ['First', 'Wait, what?\nNo.']);
      expect(c[1].start, const Duration(seconds: 5, milliseconds: 100));
    });

    test('writeSrt round-trips', () {
      final cues = parseSubtitles(_srt);
      expect(parseSubtitles(writeSrt(cues)), cues);
      expect(writeSrt(cues), startsWith('1\n00:00:01,000 --> 00:00:02,500\n'));
    });
  });

  group('translators', () {
    test('DeepL free keys use the free endpoint', () async {
      late http.Request req;
      final t = DeepLTranslator(
        'abc:fx',
        client: MockClient((r) async {
          req = r;
          return http.Response(
            jsonEncode({
              'translations': [
                {'text': 'Hola'},
                {'text': 'Dos'},
              ],
            }),
            200,
          );
        }),
      );
      expect(await t.translate(['Hello', 'Two'], target: 'es'), [
        'Hola',
        'Dos',
      ]);
      expect(req.url.host, 'api-free.deepl.com');
      expect(req.headers['Authorization'], 'DeepL-Auth-Key abc:fx');
      expect(jsonDecode(req.body)['target_lang'], 'ES');
    });

    test('Google', () async {
      late http.Request req;
      final t = GoogleTranslator(
        'k',
        client: MockClient((r) async {
          req = r;
          return http.Response(
            jsonEncode({
              'data': {
                'translations': [
                  {'translatedText': 'مرحبا'},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await t.translate(['Hello'], target: 'ar'), ['مرحبا']);
      expect(req.url.queryParameters['key'], 'k');
    });

    test('Claude: request shape and index-keyed JSON reply', () async {
      late http.Request req;
      final t = ClaudeTranslator(
        'sk-ant',
        client: MockClient((r) async {
          req = r;
          return http.Response(
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'thinking', 'thinking': ''},
                {
                  'type': 'text',
                  'text': jsonEncode({
                    'lines': [
                      {'i': 1, 'text': 'Dos'},
                      {'i': 0, 'text': 'Hola'},
                    ],
                  }),
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(await t.translate(['Hello', 'Two', 'Three'], target: 'es'), [
        'Hola',
        'Dos',
        'Three', // missing index keeps the original
      ]);
      expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(req.headers['x-api-key'], 'sk-ant');
      expect(req.headers['anthropic-version'], '2026-10-21');
      expect(req.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final body = jsonDecode(req.body) as Map;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['fallbacks'], 'default');
      expect(body.containsKey('thinking'), isFalse);
      expect(body['output_config']['format']['type'], 'json_schema');
      expect(
        jsonDecode((body['messages'] as List).single['content'] as String),
        [
          {'i': 0, 'text': 'Hello'},
          {'i': 1, 'text': 'Two'},
          {'i': 2, 'text': 'Three'},
        ],
      );
    });

    test('Claude refusal and rate limits', () async {
      final refusal = ClaudeTranslator(
        'k',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'stop_reason': 'refusal', 'content': <Object>[]}),
            200,
          ),
        ),
      );
      await expectLater(
        refusal.translate(['x'], target: 'en'),
        throwsA(isA<TranslationException>()),
      );
      final busy = ClaudeTranslator(
        'k',
        client: MockClient(
          (_) async => http.Response('', 429, headers: {'retry-after': '7'}),
        ),
      );
      await expectLater(
        busy.translate(['x'], target: 'en'),
        throwsA(
          isA<TranslationException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });
  });

  group('controller', () {
    late FakePlayerBackend backend;
    late PlayerService service;
    late Directory cache;
    late _UpperTranslator translator;
    late ProviderContainer c;

    setUp(() {
      backend = FakePlayerBackend();
      service = PlayerService(backend);
      cache = Directory.systemTemp.createTempSync('kyndrel_tr');
      translator = _UpperTranslator();
      c = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(service),
          appCacheDirProvider.overrideWithValue(cache),
          translatorProvider.overrideWithValue(translator),
          subtitleExtractorProvider.overrideWithValue(_FakeExtractor()),
        ],
      )..listen(translateProvider, (_, _) {});
    });
    tearDown(() {
      c.dispose();
      cache.deleteSync(recursive: true);
    });

    Future<void> openWithTrack({String codec = 'subrip'}) async {
      await service.open('/v/Film.mkv');
      backend
        ..emitTracks([
          {'id': '1', 'type': 'sub', 'lang': 'eng', 'codec': codec},
        ])
        ..emitProperty('sid', '1');
      await pumpEventQueue();
    }

    /// The fake mpv: a sub-add makes a new external track appear.
    void mpvAddsTracks() {
      backend.onCommand = (cmd) {
        if (cmd.first != 'sub-add') return;
        backend.emitTracks([
          {'id': '1', 'type': 'sub', 'lang': 'eng', 'codec': 'subrip'},
          {
            'id': '2',
            'type': 'sub',
            'external': 'yes',
            'external-filename': cmd[1],
          },
        ]);
      };
    }

    test(
      'translates in batches, caches, and shows it as the second line',
      () async {
        await openWithTrack();
        mpvAddsTracks();
        await c.read(translateProvider.notifier).start('ar');
        final s = c.read(translateProvider);
        expect(s.status, TranslateStatus.done, reason: s.message);
        expect(translator.calls, [2, 2, 1]);
        final srt = File(s.output!).readAsStringSync();
        expect(parseSubtitles(srt).map((e) => e.text), [
          'ONE',
          'TWO',
          'THREE',
          'FOUR',
          'FIVE',
        ]);
        expect(backend.commands.last, [
          'sub-add',
          s.output,
          'auto',
          'Translated · Arabic',
        ]);
        expect(backend.properties['secondary-sid'], '2');

        // Second time: from the cache, no requests.
        translator.calls.clear();
        await c.read(translateProvider.notifier).start('ar');
        expect(translator.calls, isEmpty);
        expect(c.read(translateProvider).status, TranslateStatus.done);
      },
    );

    test('image subtitles and missing keys fail with a message', () async {
      await openWithTrack(codec: 'hdmv_pgs_subtitle');
      await c.read(translateProvider.notifier).start('ar');
      expect(c.read(translateProvider).status, TranslateStatus.failed);
      expect(c.read(translateProvider).message, contains('Image'));
    });

    test('a rate limit is retried; a bad key is not', () async {
      await openWithTrack();
      mpvAddsTracks();
      translator.failures = [
        const TranslationException('busy', retryAfter: Duration.zero),
      ];
      await c.read(translateProvider.notifier).start('es');
      expect(c.read(translateProvider).status, TranslateStatus.done);

      translator
        ..failures = [
          const TranslationException('Claude rejected the API key.'),
        ]
        ..calls.clear();
      await c.read(translateProvider.notifier).start('fr');
      expect(c.read(translateProvider).status, TranslateStatus.failed);
      expect(translator.calls, isEmpty, reason: 'no retry after a key error');
    });
  });
}

class _UpperTranslator implements Translator {
  final calls = <int>[];
  List<TranslationException> failures = [];

  @override
  String get id => 'test';

  @override
  int get batchSize => 2;

  @override
  Future<List<String>> translate(
    List<String> lines, {
    required String target,
  }) async {
    if (failures.isNotEmpty) throw failures.removeAt(0);
    calls.add(lines.length);
    return [for (final l in lines) l.toUpperCase()];
  }
}

class _FakeExtractor implements SubtitleExtractor {
  @override
  Future<List<Cue>> cues(
    String source,
    MediaTrack track,
    List<MediaTrack> all,
  ) async => [
    for (final (i, w) in ['one', 'two', 'three', 'four', 'five'].indexed)
      Cue(Duration(seconds: i * 2), Duration(seconds: i * 2 + 1), w),
  ];
}
