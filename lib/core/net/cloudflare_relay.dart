import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Puts Kyndrel's Watch Together relay on the user's own Cloudflare
/// account (task 9.11, as Harbor does): a Worker with one Durable Object
/// per room, on the free plan. Needs an API token allowed to edit Workers.
class CloudflareRelay {
  new({required this.token, http.Client? client})
    : _http = client ?? http.Client();

  final String token;
  final http.Client _http;

  static const api = 'https://api.cloudflare.com/client/v4';
  static const scriptName = 'kyndrel-together';
  static const timeout = Duration(seconds: 30);

  Map<String, String> get _auth => {'Authorization': 'Bearer $token'};

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Object? body,
  }) async {
    final req = http.Request(method, Uri.parse('$api$path'))
      ..headers.addAll(_auth);
    if (body != null) {
      req
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    final r = await http.Response.fromStream(
      await _http.send(req).timeout(timeout),
    );
    return _result(r);
  }

  static Map<String, Object?> _result(http.Response r) {
    Map<String, Object?> json;
    try {
      json = (jsonDecode(r.body) as Map).cast();
    } on Object {
      throw CloudflareException('Cloudflare answered ${r.statusCode}.');
    }
    if (json['success'] != true) {
      final errors = (json['errors'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e['message'])
          .join('; ');
      throw CloudflareException(
        errors.isEmpty ? 'Cloudflare answered ${r.statusCode}.' : errors,
        status: r.statusCode,
      );
    }
    return json;
  }

  /// The account the token can use (the first one).
  Future<String> accountId() async {
    final r = await _call('GET', '/accounts');
    final list = r['result'] as List? ?? const [];
    final first = list.whereType<Map<dynamic, dynamic>>().firstOrNull;
    if (first == null) {
      throw const CloudflareException('This token sees no Cloudflare account.');
    }
    return '${first['id']}';
  }

  /// Uploads [workerJs] and turns on its workers.dev address; returns the
  /// relay's address, `wss://kyndrel-together.<you>.workers.dev`.
  Future<Uri> deploy(String workerJs) async {
    final account = await accountId();
    final sub = await _call('GET', '/accounts/$account/workers/subdomain');
    final subdomain = (sub['result'] as Map?)?['subdomain'];
    if (subdomain is! String || subdomain.isEmpty) {
      throw const CloudflareException(
        'Open Workers & Pages in the Cloudflare dashboard once to get a '
        'workers.dev address, then try again.',
      );
    }
    var exists = true;
    try {
      await _call('GET', '/accounts/$account/workers/scripts/$scriptName');
    } on CloudflareException catch (e) {
      if (e.status != 404) rethrow;
      exists = false;
    }
    final bindings = [
      {
        'type': 'durable_object_namespace',
        'name': 'ROOM',
        'class_name': 'Room',
      },
    ];
    Map<String, Object?> metadata({required bool migrate}) => {
      'main_module': 'worker.js',
      'compatibility_date': '2026-05-01',
      'bindings': bindings,
      if (migrate)
        'migrations': {
          'tag': 'v1',
          'new_sqlite_classes': ['Room'],
        },
    };
    try {
      await _upload(account, workerJs, metadata(migrate: !exists));
    } on CloudflareException {
      // A half-made earlier attempt: the other way round.
      await _upload(account, workerJs, metadata(migrate: exists));
    }
    await _call(
      'POST',
      '/accounts/$account/workers/scripts/$scriptName/subdomain',
      body: {'enabled': true},
    );
    return Uri.parse('wss://$scriptName.$subdomain.workers.dev');
  }

  Future<void> _upload(
    String account,
    String workerJs,
    Map<String, Object?> metadata,
  ) async {
    final req =
        http.MultipartRequest(
            'PUT',
            Uri.parse('$api/accounts/$account/workers/scripts/$scriptName'),
          )
          ..headers.addAll(_auth)
          ..files.add(
            http.MultipartFile.fromString('metadata', jsonEncode(metadata)),
          )
          ..files.add(
            http.MultipartFile.fromString(
              'worker.js',
              workerJs,
              filename: 'worker.js',
              contentType: _jsModule,
            ),
          );
    _result(
      await http.Response.fromStream(await _http.send(req).timeout(timeout)),
    );
  }

  void close() => _http.close();
}

final _jsModule = MediaType('application', 'javascript+module');

class CloudflareException implements Exception {
  const new(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}
