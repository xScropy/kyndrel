import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// UPnP/DLNA media servers on the network (NAS, Plex, Jellyfin, Windows
/// media sharing) and their folders (task 8.7), like VLC's "Local network".

const mediaServerType = 'urn:schemas-upnp-org:device:MediaServer:1';
const _contentDirectory = 'urn:schemas-upnp-org:service:ContentDirectory:1';

/// An SSDP search for [target].
String ssdpSearchFor(String target, {int mx = 2}) =>
    'M-SEARCH * HTTP/1.1\r\n'
    'HOST: 239.255.255.250:1900\r\n'
    'MAN: "ssdp:discover"\r\n'
    'MX: $mx\r\n'
    'ST: $target\r\n\r\n';

/// The `LOCATION` of an SSDP reply whose type contains [kind].
Uri? ssdpLocation(String reply, String kind) {
  final headers = <String, String>{};
  for (final line in const LineSplitter().convert(reply).skip(1)) {
    final i = line.indexOf(':');
    if (i > 0) {
      headers[line.substring(0, i).trim().toLowerCase()] = line
          .substring(i + 1)
          .trim();
    }
  }
  final st = headers['st'] ?? headers['nt'] ?? '';
  if (!st.contains(kind)) return null;
  final loc = headers['location'];
  return loc == null ? null : Uri.tryParse(loc);
}

@immutable
class DlnaServer {
  const new({required this.id, required this.name, required this.control});

  final String id;
  final String name;

  /// The ContentDirectory control URL.
  final Uri control;
}

/// One folder or file on a media server.
@immutable
class DlnaEntry {
  const new({
    required this.id,
    required this.title,
    required this.isFolder,
    this.url,
    this.duration,
    this.size,
  });

  /// The object id to browse into (folders).
  final String id;
  final String title;
  final bool isFolder;

  /// Where a file streams from (HTTP).
  final Uri? url;
  final Duration? duration;
  final int? size;
}

/// A media server from its device description, or null without a
/// ContentDirectory service.
DlnaServer? parseServerDescription(Uri location, String xmlText) {
  final doc = XmlDocument.parse(xmlText);
  String? text(XmlElement e, String name) =>
      e.findAllElements(name).firstOrNull?.innerText.trim();
  final device = doc.findAllElements('device').firstOrNull;
  if (device == null) return null;
  final urlBase = text(doc.rootElement, 'URLBase');
  final base = urlBase == null || urlBase.isEmpty
      ? location
      : Uri.tryParse(urlBase) ?? location;
  for (final s in device.findAllElements('service')) {
    if (text(s, 'serviceType') == _contentDirectory) {
      final c = text(s, 'controlURL');
      if (c == null) return null;
      return DlnaServer(
        id: text(device, 'UDN') ?? location.toString(),
        name: text(device, 'friendlyName') ?? location.host,
        control: base.resolve(c),
      );
    }
  }
  return null;
}

/// `1:02:03.000` → a duration (DIDL `res@duration`).
Duration? parseDidlDuration(String? v) {
  if (v == null) return null;
  final parts = v.split(':');
  if (parts.length != 3) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = double.tryParse(parts[2]);
  if (h == null || m == null || s == null) return null;
  return Duration(milliseconds: ((h * 3600 + m * 60 + s) * 1000).round());
}

/// The folders and video/audio files of a DIDL-Lite listing.
List<DlnaEntry> parseDidl(String didl) {
  final doc = XmlDocument.parse(didl);
  String? child(XmlElement e, String local) => e.childElements
      .where((c) => c.name.local == local)
      .firstOrNull
      ?.innerText;
  final out = <DlnaEntry>[];
  for (final c in doc.rootElement.childElements) {
    final title = child(c, 'title') ?? '?';
    final id = c.getAttribute('id') ?? '';
    if (c.name.local == 'container') {
      out.add(DlnaEntry(id: id, title: title, isFolder: true));
    } else if (c.name.local == 'item') {
      final cls = child(c, 'class') ?? '';
      if (!cls.contains('videoItem') && !cls.contains('audioItem')) continue;
      final res = c.childElements
          .where((e) => e.name.local == 'res')
          .firstOrNull;
      final url = Uri.tryParse(res?.innerText.trim() ?? '');
      if (url == null || !url.hasScheme) continue;
      out.add(
        DlnaEntry(
          id: id,
          title: title,
          isFolder: false,
          url: url,
          duration: parseDidlDuration(res?.getAttribute('duration')),
          size: int.tryParse(res?.getAttribute('size') ?? ''),
        ),
      );
    }
  }
  return out;
}

/// Finds media servers and browses them.
class DlnaBrowser {
  new({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Media servers that answer within [timeout].
  Future<List<DlnaServer>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final locations = <Uri>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null) return;
        final loc = ssdpLocation(
          utf8.decode(d.data, allowMalformed: true),
          'MediaServer',
        );
        if (loc != null) locations.add(loc);
      });
      final msg = utf8.encode(ssdpSearchFor(mediaServerType));
      for (var i = 0; i < 2; i++) {
        socket.send(msg, InternetAddress('239.255.255.250'), 1900);
        await Future<void>.delayed(timeout ~/ 2);
      }
    } on SocketException {
      // No network.
    } finally {
      socket?.close();
    }
    final found = <String, DlnaServer>{};
    for (final loc in locations) {
      try {
        final r = await _http.get(loc).timeout(const Duration(seconds: 3));
        final s = parseServerDescription(loc, r.body);
        if (s != null) found[s.id] = s;
      } on Object {
        // Doesn't answer: skip.
      }
    }
    return found.values.toList();
  }

  /// The children of [objectId] ("0" is the top).
  Future<List<DlnaEntry>> browse(DlnaServer server, String objectId) async {
    final body = [
      '<?xml version="1.0"?>',
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ',
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">',
      '<s:Body><u:Browse xmlns:u="$_contentDirectory">',
      '<ObjectID>${const HtmlEscape().convert(objectId)}</ObjectID>',
      '<BrowseFlag>BrowseDirectChildren</BrowseFlag>',
      '<Filter>*</Filter><StartingIndex>0</StartingIndex>',
      '<RequestedCount>2000</RequestedCount><SortCriteria></SortCriteria>',
      '</u:Browse></s:Body></s:Envelope>',
    ].join();
    final r = await _http
        .post(
          server.control,
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPAction': '"$_contentDirectory#Browse"',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw HttpException('The server answered ${r.statusCode}');
    }
    final soap = XmlDocument.parse(utf8.decode(r.bodyBytes));
    final result = soap.findAllElements('Result').firstOrNull?.innerText;
    if (result == null || result.isEmpty) return const [];
    return parseDidl(result);
  }

  void close() => _http.close();
}
