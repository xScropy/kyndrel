import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kyndrel/core/player/remote_target.dart';
import 'package:kyndrel/features/cast/cast_device.dart';
import 'package:kyndrel/features/cast/cast_session.dart';
import 'package:xml/xml.dart';

const _avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
const _rendering = 'urn:schemas-upnp-org:service:RenderingControl:1';
const mediaRendererType = 'urn:schemas-upnp-org:device:MediaRenderer:1';

/// The SSDP search for media renderers.
String ssdpSearch({int mx = 2}) =>
    'M-SEARCH * HTTP/1.1\r\n'
    'HOST: 239.255.255.250:1900\r\n'
    'MAN: "ssdp:discover"\r\n'
    'MX: $mx\r\n'
    'ST: $mediaRendererType\r\n\r\n';

/// The `LOCATION` header of an SSDP reply, if it's a media renderer.
Uri? parseSsdpReply(String reply) {
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
  if (!st.contains('MediaRenderer')) return null;
  final loc = headers['location'];
  return loc == null ? null : Uri.tryParse(loc);
}

/// A [CastDevice] from a UPnP device description, or null if it has no
/// AVTransport service.
CastDevice? parseDeviceDescription(Uri location, String xmlText) {
  final doc = XmlDocument.parse(xmlText);
  String? text(XmlElement e, String name) =>
      e.findAllElements(name).firstOrNull?.innerText.trim();
  final device = doc.findAllElements('device').firstOrNull;
  if (device == null) return null;
  final urlBase = text(doc.rootElement, 'URLBase');
  final base = urlBase == null || urlBase.isEmpty
      ? location
      : Uri.tryParse(urlBase) ?? location;
  Uri? control(String type) {
    for (final s in device.findAllElements('service')) {
      if (text(s, 'serviceType') == type) {
        final c = text(s, 'controlURL');
        return c == null ? null : base.resolve(c);
      }
    }
    return null;
  }

  final av = control(_avTransport);
  if (av == null) return null;
  return CastDevice(
    id: 'dlna:${text(device, 'UDN') ?? location}',
    name: text(device, 'friendlyName') ?? location.host,
    kind: CastKind.dlna,
    host: location.host,
    port: location.port,
    avTransportUrl: av,
    renderingControlUrl: control(_rendering),
  );
}

/// Finds DLNA renderers on the network (SSDP over UDP multicast).
Future<List<CastDevice>> discoverDlna({
  Duration timeout = const Duration(seconds: 3),
  http.Client? client,
}) async {
  final http_ = client ?? http.Client();
  final found = <String, CastDevice>{};
  final locations = <Uri>{};
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = socket!.receive();
      if (d == null) return;
      final loc = parseSsdpReply(utf8.decode(d.data, allowMalformed: true));
      if (loc != null) locations.add(loc);
    });
    final msg = utf8.encode(ssdpSearch());
    for (var i = 0; i < 2; i++) {
      socket.send(msg, InternetAddress('239.255.255.250'), 1900);
      await Future<void>.delayed(timeout ~/ 2);
    }
  } on SocketException {
    // No network: nothing found.
  } finally {
    socket?.close();
  }
  for (final loc in locations) {
    try {
      final r = await http_.get(loc).timeout(const Duration(seconds: 3));
      final d = parseDeviceDescription(loc, r.body);
      if (d != null) found[d.id] = d;
    } on Object {
      // Skip devices that don't answer.
    }
  }
  if (client == null) http_.close();
  return found.values.toList();
}

/// `01:02:03` for UPnP time values.
String upnpTime(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

Duration? parseUpnpTime(String? s) {
  final m = RegExp(r'^(\d+):(\d{2}):(\d{2})').firstMatch(s ?? '');
  if (m == null) return null;
  return Duration(
    hours: int.parse(m.group(1)!),
    minutes: int.parse(m.group(2)!),
    seconds: int.parse(m.group(3)!),
  );
}

String soapEnvelope(String service, String action, Map<String, String> args) {
  final b = XmlBuilder();
  b
    ..processing('xml', 'version="1.0" encoding="utf-8"')
    ..element(
      's:Envelope',
      attributes: {
        'xmlns:s': 'http://schemas.xmlsoap.org/soap/envelope/',
        's:encodingStyle': 'http://schemas.xmlsoap.org/soap/encoding/',
      },
      nest: () {
        b.element(
          's:Body',
          nest: () {
            b.element(
              'u:$action',
              attributes: {'xmlns:u': service},
              nest: () {
                for (final e in args.entries) {
                  b.element(e.key, nest: e.value);
                }
              },
            );
          },
        );
      },
    );
  return b.buildDocument().toXmlString();
}

/// DIDL-Lite metadata so renderers show a title and know the format.
String didl(String title, String url, String mime, {Uri? subtitle}) {
  final b = XmlBuilder();
  b.element(
    'DIDL-Lite',
    attributes: {
      'xmlns': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
      'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
      'xmlns:upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
      'xmlns:sec': 'http://www.sec.co.kr/',
    },
    nest: () {
      b.element(
        'item',
        attributes: {'id': '0', 'parentID': '-1', 'restricted': '1'},
        nest: () {
          b
            ..element('dc:title', nest: title)
            ..element('upnp:class', nest: 'object.item.videoItem')
            ..element(
              'res',
              attributes: {'protocolInfo': 'http-get:*:$mime:*'},
              nest: url,
            );
          if (subtitle != null) {
            b.element(
              'sec:CaptionInfoEx',
              attributes: {'sec:type': 'srt'},
              nest: subtitle.toString(),
            );
          }
        },
      );
    },
  );
  return b.buildDocument().toXmlString();
}

/// Plays on a DLNA/UPnP renderer through AVTransport (task 4.4).
class DlnaSession implements CastSession {
  new(this.device, {http.Client? client}) : _http = client ?? http.Client();

  final CastDevice device;
  final http.Client _http;
  final _status = StreamController<RemoteStatus>.broadcast();
  Timer? _poll;
  bool _wasPlaying = false;

  @override
  String get name => device.name;

  @override
  Stream<RemoteStatus> get status => _status.stream;

  Future<XmlDocument> _call(
    String service,
    Uri url,
    String action, [
    Map<String, String> args = const {},
  ]) async {
    final r = await _http
        .post(
          url,
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPAction': '"$service#$action"',
          },
          body: soapEnvelope(service, action, args),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw HttpException('$action failed (${r.statusCode})');
    }
    return XmlDocument.parse(r.body);
  }

  Future<XmlDocument> _av(
    String action, [
    Map<String, String> args = const {},
  ]) => _call(_avTransport, device.avTransportUrl!, action, {
    'InstanceID': '0',
    ...args,
  });

  Future<void> load(
    Uri url, {
    required String contentType,
    required String title,
    Duration startAt = Duration.zero,
    Uri? subtitleUrl,
  }) async {
    await _av('SetAVTransportURI', {
      'CurrentURI': url.toString(),
      'CurrentURIMetaData': didl(
        title,
        url.toString(),
        contentType,
        subtitle: subtitleUrl,
      ),
    });
    await _av('Play', {'Speed': '1'});
    if (startAt > const Duration(seconds: 1)) {
      // Many renderers only accept a seek once playback has started.
      await Future<void>.delayed(const Duration(seconds: 1));
      await seek(startAt);
    }
    _poll = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    try {
      final pos = await _av('GetPositionInfo');
      final info = await _av('GetTransportInfo');
      String? v(XmlDocument d, String n) =>
          d.findAllElements(n).firstOrNull?.innerText;
      final state = v(info, 'CurrentTransportState');
      final playing = state == 'PLAYING' || state == 'TRANSITIONING';
      final finished = _wasPlaying && state == 'STOPPED';
      _wasPlaying = playing;
      if (!_status.isClosed) {
        _status.add(
          RemoteStatus(
            position: parseUpnpTime(v(pos, 'RelTime')) ?? Duration.zero,
            duration: parseUpnpTime(v(pos, 'TrackDuration')),
            playing: playing,
            finished: finished,
          ),
        );
      }
    } on Object {
      // Renderer busy; try again next tick.
    }
  }

  @override
  Future<void> loadMedia(CastMedia m) => load(
    m.url,
    contentType: m.contentType,
    title: m.title,
    startAt: m.startAt,
    subtitleUrl: m.subtitleUrl,
  );

  @override
  Future<void> play() async {
    await _av('Play', {'Speed': '1'});
  }

  @override
  Future<void> pause() async {
    await _av('Pause');
  }

  @override
  Future<void> seek(Duration position) async {
    await _av('Seek', {'Unit': 'REL_TIME', 'Target': upnpTime(position)});
  }

  @override
  Future<void> setVolume(double volume) async {
    final url = device.renderingControlUrl;
    if (url == null) return;
    await _call(_rendering, url, 'SetVolume', {
      'InstanceID': '0',
      'Channel': 'Master',
      'DesiredVolume': '${(volume.clamp(0, 1) * 100).round()}',
    });
  }

  @override
  Future<void> stop() async {
    _poll?.cancel();
    try {
      await _av('Stop');
    } finally {
      await _status.close();
      _http.close();
    }
  }
}
