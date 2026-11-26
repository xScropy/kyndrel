import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

@immutable
class DavEntry {
  const new({
    required this.url,
    required this.name,
    required this.isFolder,
    this.size,
  });

  final Uri url;
  final String name;
  final bool isFolder;
  final int? size;
}

class WebDavException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `Authorization: Basic …` for [user] and [password].
String basicAuthHeader(String user, String password) =>
    'Authorization: Basic ${base64.encode(utf8.encode('$user:$password'))}';

/// Lists WebDAV folders with PROPFIND (task 4.5).
class WebDavClient {
  new({this.user = '', this.password = '', http.Client? client})
    : _http = client ?? http.Client();

  final String user;
  final String password;
  final http.Client _http;

  List<String> get headers =>
      user.isEmpty ? const [] : [basicAuthHeader(user, password)];

  Future<List<DavEntry>> list(Uri folder) async {
    final req = http.Request('PROPFIND', folder)
      ..headers['Depth'] = '1'
      ..headers['Content-Type'] = 'application/xml'
      ..body = const [
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>',
        '<d:displayname/><d:resourcetype/><d:getcontentlength/>',
        '</d:prop></d:propfind>',
      ].join();
    if (user.isNotEmpty) {
      req.headers['Authorization'] =
          'Basic ${base64.encode(utf8.encode('$user:$password'))}';
    }
    final res = await http.Response.fromStream(
      await _http.send(req).timeout(const Duration(seconds: 15)),
    );
    if (res.statusCode == 401) {
      throw const WebDavException('Wrong user name or password.');
    }
    if (res.statusCode != 207 && res.statusCode != 200) {
      throw WebDavException('The server answered ${res.statusCode}.');
    }
    return parseMultistatus(folder, utf8.decode(res.bodyBytes));
  }

  void close() => _http.close();
}

/// Entries of a PROPFIND reply, without the folder itself, folders first.
List<DavEntry> parseMultistatus(Uri folder, String xmlText) {
  final doc = XmlDocument.parse(xmlText);
  final self = folder.path.endsWith('/') ? folder.path : '${folder.path}/';
  final out = <DavEntry>[];
  for (final r in doc.findAllElements('response', namespaceUri: 'DAV:')) {
    final href = r
        .findElements('href', namespaceUri: 'DAV:')
        .firstOrNull
        ?.innerText;
    if (href == null) continue;
    final url = folder.resolve(href);
    final path = Uri.decodeComponent(url.path);
    if (path == Uri.decodeComponent(self) ||
        path == Uri.decodeComponent(self.substring(0, self.length - 1))) {
      continue;
    }
    final isFolder = r
        .findAllElements('collection', namespaceUri: 'DAV:')
        .isNotEmpty;
    final display = r
        .findAllElements('displayname', namespaceUri: 'DAV:')
        .firstOrNull
        ?.innerText;
    final segs = path.split('/').where((s) => s.isNotEmpty);
    out.add(
      DavEntry(
        url: url,
        name: display == null || display.isEmpty ? segs.last : display,
        isFolder: isFolder,
        size: int.tryParse(
          r
                  .findAllElements('getcontentlength', namespaceUri: 'DAV:')
                  .firstOrNull
                  ?.innerText ??
              '',
        ),
      ),
    );
  }
  out.sort((a, b) {
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}
