import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A translation backend (task 4.2).
abstract interface class Translator {
  /// Short name for cache keys and the UI.
  String get id;

  /// Lines per request.
  int get batchSize;

  /// Translates each of [lines] into [target] (ISO 639-1). The result has
  /// the same length and order.
  Future<List<String>> translate(List<String> lines, {required String target});
}

class TranslationException implements Exception {
  const new(this.message, {this.retryAfter});
  final String message;

  /// Set for rate limits: wait this long, then try again.
  final Duration? retryAfter;

  @override
  String toString() => message;
}

Never _fail(http.Response r, String service) {
  if (r.statusCode == 429 || r.statusCode == 529) {
    final s = int.tryParse(r.headers['retry-after'] ?? '');
    throw TranslationException(
      '$service is busy.',
      retryAfter: Duration(seconds: s ?? 5),
    );
  }
  if (r.statusCode == 401 || r.statusCode == 403) {
    throw TranslationException('$service rejected the API key.');
  }
  if (r.statusCode == 456) {
    throw TranslationException('$service quota exceeded.');
  }
  throw TranslationException('$service error ${r.statusCode}.');
}

/// DeepL API (free keys end in `:fx` and use api-free.deepl.com).
class DeepLTranslator implements Translator {
  new(this.apiKey, {http.Client? client}) : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  @override
  String get id => 'deepl';

  @override
  int get batchSize => 50;

  Uri get _endpoint => Uri.parse(
    apiKey.endsWith(':fx')
        ? 'https://api-free.deepl.com/v2/translate'
        : 'https://api.deepl.com/v2/translate',
  );

  @override
  Future<List<String>> translate(
    List<String> lines, {
    required String target,
  }) async {
    final r = await _http.post(
      _endpoint,
      headers: {
        'Authorization': 'DeepL-Auth-Key $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': lines,
        'target_lang': target.toUpperCase(),
        'preserve_formatting': true,
      }),
    );
    if (r.statusCode != 200) _fail(r, 'DeepL');
    final list =
        (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['translations'] as List;
    return [for (final t in list) (t as Map)['text'] as String];
  }
}

/// Google Cloud Translation API v2 (API key).
class GoogleTranslator implements Translator {
  new(this.apiKey, {http.Client? client}) : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  @override
  String get id => 'google';

  @override
  int get batchSize => 100;

  @override
  Future<List<String>> translate(
    List<String> lines, {
    required String target,
  }) async {
    final r = await _http.post(
      Uri.parse('https://translation.googleapis.com/language/translate/v2')
          .replace(queryParameters: {'key': apiKey}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'q': lines, 'target': target, 'format': 'text'}),
    );
    if (r.statusCode != 200) _fail(r, 'Google Translate');
    final data = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['data'] as Map;
    return [
      for (final t in data['translations'] as List)
        (t as Map)['translatedText'] as String,
    ];
  }
}

/// Claude through the Messages API, with a JSON schema so the reply is a
/// list with exactly one translation per input line.
class ClaudeTranslator implements Translator {
  new(this.apiKey, {http.Client? client, this.model = defaultModel})
    : _http = client ?? http.Client();

  static const defaultModel = 'claude-opus-5-5';
  static final Uri endpoint = Uri.parse(
    'https://api.anthropic.com/v1/messages',
  );

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  String get id => 'claude';

  @override
  int get batchSize => 80;

  static const Map<String, Object> _schema = {
    'type': 'object',
    'properties': {
      'lines': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'i': {'type': 'integer'},
            'text': {'type': 'string'},
          },
          'required': ['i', 'text'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['lines'],
    'additionalProperties': false,
  };

  @override
  Future<List<String>> translate(
    List<String> lines, {
    required String target,
  }) async {
    final input = [
      for (final (i, t) in lines.indexed) {'i': i, 'text': t},
    ];
    final r = await _http.post(
      endpoint,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2026-10-21',
        // Re-run a policy refusal on a fallback model inside the same call.
        'anthropic-beta': 'server-side-fallback-2026-07-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 16000,
        'fallbacks': 'default',
        'output_config': {
          'effort': 'medium',
          'format': {'type': 'json_schema', 'schema': _schema},
        },
        'system':
            'You translate film and TV subtitles. Translate each line into '
            'the language with ISO 639-1 code "$target". Keep the meaning, '
            'tone and line breaks; keep names; keep it short enough to read '
            'on screen. Return every input index exactly once.',
        'messages': [
          {'role': 'user', 'content': jsonEncode(input)},
        ],
      }),
    );
    if (r.statusCode != 200) _fail(r, 'Claude');
    final body = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)
        .cast<String, Object?>();
    if (body['stop_reason'] == 'refusal') {
      throw const TranslationException('Claude declined to translate this.');
    }
    if (body['stop_reason'] == 'max_tokens') {
      throw const TranslationException('Claude ran out of room; try again.');
    }
    final text = (body['content'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text']! as String)
        .join();
    final out = List<String?>.filled(lines.length, null);
    for (final item
        in ((jsonDecode(text) as Map)['lines'] as List)
            .cast<Map<String, Object?>>()) {
      final i = (item['i']! as num).toInt();
      if (i >= 0 && i < out.length) out[i] = item['text']! as String;
    }
    // A missing line keeps the original rather than shifting the rest.
    return [for (final (i, t) in out.indexed) t ?? lines[i]];
  }
}
