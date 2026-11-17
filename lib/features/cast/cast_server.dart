import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Serves the file being cast to devices on the local network (task 4.4):
/// the file itself with HTTP Range support, an optional WebVTT subtitle,
/// and, when the device can't play the codecs, a live FFmpeg transcode.
class CastServer {
  new _(this._server, this.host);

  /// Binds on all interfaces; [host] is the LAN address devices should use.
  static Future<CastServer> start({String? host}) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final s = CastServer._(server, host ?? await lanAddress() ?? '127.0.0.1');
    server.listen(s._handle);
    return s;
  }

  final HttpServer _server;
  final String host;
  final String _token = List.generate(
    16,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();

  String? _file;
  String? _vtt;

  /// FFmpeg used for transcoding, or null to never transcode.
  String? ffmpeg = 'ffmpeg';

  int get port => _server.port;

  static const _types = {
    '.mp4': 'video/mp4',
    '.m4v': 'video/mp4',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
    '.avi': 'video/x-msvideo',
    '.mov': 'video/quicktime',
    '.ts': 'video/mp2t',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.flac': 'audio/flac',
    '.ogg': 'audio/ogg',
    '.opus': 'audio/ogg',
    '.wav': 'audio/wav',
  };

  /// "Seekable by byte range, streaming" for DLNA renderers.
  static const dlnaFeatures =
      'DLNA.ORG_OP=01;DLNA.ORG_CI=0;'
      'DLNA.ORG_FLAGS=01700000000000000000000000000000';

  static String contentTypeOf(String path) =>
      _types[p.extension(path).toLowerCase()] ?? 'video/mp4';

  /// Makes [file] available; returns its URL. [vtt] is optional WebVTT text.
  Uri serve(String file, {String? vtt}) {
    _file = file;
    _vtt = vtt;
    return mediaUrl;
  }

  Uri get mediaUrl =>
      Uri.http('$host:$port', '/$_token/media${p.extension(_file ?? '.mp4')}');
  Uri? get subtitleUrl =>
      _vtt == null ? null : Uri.http('$host:$port', '/$_token/subs.vtt');

  /// Live transcode (H.264/AAC fragmented MP4) starting at [from].
  Uri transcodeUrl(Duration from) => Uri.http(
    '$host:$port',
    '/$_token/transcode.mp4',
    {'t': '${from.inSeconds}'},
  );

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Range, Content-Type')
      ..set('Access-Control-Expose-Headers', 'Content-Range, Content-Length');
    try {
      final segs = req.uri.pathSegments;
      if (segs.length != 2 || segs.first != _token) {
        res.statusCode = HttpStatus.notFound;
      } else if (req.method == 'OPTIONS') {
        res.statusCode = HttpStatus.noContent;
      } else if (segs[1] == 'subs.vtt' && _vtt != null) {
        res.headers.contentType = ContentType('text', 'vtt', charset: 'utf-8');
        res.write(_vtt);
      } else if (segs[1].startsWith('media') && _file != null) {
        await _serveFile(req, File(_file!));
        return;
      } else if (segs[1] == 'transcode.mp4' && _file != null) {
        await _transcode(req);
        return;
      } else {
        res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    } on Object {
      // Devices drop connections all the time when seeking.
      try {
        await res.close();
      } on Object {
        // Already closed.
      }
    }
  }

  Future<void> _serveFile(HttpRequest req, File file) async {
    final res = req.response;
    final length = await file.length();
    res.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..contentType = ContentType.parse(contentTypeOf(file.path))
      // DLNA renderers want to know they may seek.
      ..set('transferMode.dlna.org', 'Streaming')
      ..set('contentFeatures.dlna.org', dlnaFeatures);
    var start = 0;
    var end = length - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null
        ? null
        : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    if (m != null) {
      final a = m.group(1)!;
      final b = m.group(2)!;
      if (a.isEmpty && b.isNotEmpty) {
        start = max(0, length - int.parse(b));
      } else {
        start = int.parse(a.isEmpty ? '0' : a);
        if (b.isNotEmpty) end = min(end, int.parse(b));
      }
      if (start >= length || start > end) {
        res
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        await res.close();
        return;
      }
      res
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$length',
        );
    }
    res.contentLength = end - start + 1;
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    await res.addStream(file.openRead(start, end + 1));
    await res.close();
  }

  Future<void> _transcode(HttpRequest req) async {
    final res = req.response;
    final exe = ffmpeg;
    if (exe == null) {
      res.statusCode = HttpStatus.notImplemented;
      await res.close();
      return;
    }
    final t = int.tryParse(req.uri.queryParameters['t'] ?? '') ?? 0;
    res.headers.contentType = ContentType.parse('video/mp4');
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    final proc = await Process.start(exe, [
      '-nostdin', '-loglevel', 'error', '-ss', '$t', '-i', _file!, //
      '-map', '0:v:0?', '-map', '0:a:0?',
      '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '21',
      '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-ac', '2',
      '-f', 'mp4', '-movflags', 'frag_keyframe+empty_moov+default_base_moof',
      'pipe:1',
    ]);
    unawaited(proc.stderr.drain<void>());
    try {
      await res.addStream(proc.stdout);
    } finally {
      proc.kill();
      await res.close();
    }
  }

  /// The first private IPv4 address of this machine.
  static Future<String?> lanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    String? fallback;
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (a.isLoopback || a.isLinkLocal) continue;
        final ip = a.address;
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
          return ip;
        }
        fallback ??= ip;
      }
    }
    return fallback;
  }
}

/// Whether a Chromecast can play the file as it is (otherwise transcode).
/// Codec names are mpv's (`h264`, `hevc`, `vp9`, `aac`...).
bool chromecastCanPlay({
  required String? videoCodec,
  required String? audioCodec,
  required String path,
}) {
  const video = {'h264', 'vp8', 'vp9'};
  const audio = {'aac', 'mp3', 'opus', 'vorbis', 'flac'};
  const containers = {'.mp4', '.m4v', '.webm', '.mkv', '.mp3', '.m4a', '.ogg'};
  if (!containers.contains(p.extension(path).toLowerCase())) return false;
  if (videoCodec != null && !video.contains(videoCodec)) return false;
  if (audioCodec != null && !audio.contains(audioCodec)) return false;
  return true;
}
