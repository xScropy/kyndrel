import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One entry of an FTP folder.
@immutable
class FtpEntry {
  const new({required this.name, required this.isFolder, this.size});

  final String name;
  final bool isFolder;
  final int? size;
}

class FtpException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Entries of an `MLSD` reply (RFC 3659), without `.` and `..`.
List<FtpEntry> parseMlsd(String text) {
  final out = <FtpEntry>[];
  for (final line in const LineSplitter().convert(text)) {
    final space = line.indexOf(' ');
    if (space < 0) continue;
    final name = line.substring(space + 1);
    final facts = <String, String>{};
    for (final f in line.substring(0, space).split(';')) {
      final eq = f.indexOf('=');
      if (eq > 0) facts[f.substring(0, eq).toLowerCase()] = f.substring(eq + 1);
    }
    final type = facts['type']?.toLowerCase();
    if (type == 'cdir' || type == 'pdir' || name == '.' || name == '..') {
      continue;
    }
    out.add(
      FtpEntry(
        name: name,
        isFolder: type == 'dir',
        size: int.tryParse(facts['size'] ?? ''),
      ),
    );
  }
  return out;
}

/// Entries of a Unix-style `LIST` reply (servers without MLSD).
List<FtpEntry> parseUnixList(String text) {
  final out = <FtpEntry>[];
  final re = RegExp(
    r'^([dl-])[rwxsStT-]{9}\S*\s+\d+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+\S+\s+\S+\s+(.+)$',
  );
  for (final line in const LineSplitter().convert(text)) {
    final m = re.firstMatch(line.trim());
    if (m == null) continue;
    var name = m.group(3)!;
    if (m.group(1) == 'l') name = name.split(' -> ').first;
    if (name == '.' || name == '..') continue;
    out.add(
      FtpEntry(
        name: name,
        isFolder: m.group(1) == 'd',
        size: int.tryParse(m.group(2)!),
      ),
    );
  }
  return out;
}

/// A small passive-mode FTP client: enough to list folders (task 8.7).
/// Playback opens the `ftp://` URL in mpv itself.
class FtpClient {
  new({required this.host, this.port = 21, this.user = '', this.password = ''});

  final String host;
  final int port;
  final String user;
  final String password;

  static const timeout = Duration(seconds: 15);

  /// The folders and files in [path].
  Future<List<FtpEntry>> list(String path) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final control = _Control(socket);
    try {
      await control.expect([220]);
      await control
          .send('USER ${user.isEmpty ? 'anonymous' : user}', [230, 331])
          .then((code) async {
            if (code == 331) {
              await control.send(
                'PASS ${user.isEmpty ? 'kyndrel@' : password}',
                [230, 202],
              );
            }
          });
      await control.send('TYPE I', [200]);
      final dir = path.isEmpty ? '/' : path;
      // MLSD first (exact facts), LIST for older servers.
      for (final (command, parse) in [
        ('MLSD', parseMlsd),
        ('LIST', parseUnixList),
      ]) {
        final data = await _passive(control);
        final code = await control.send('$command $dir', [125, 150, 500, 502]);
        if (code >= 500) {
          await data.close();
          continue;
        }
        final bytes = await data
            .fold<List<int>>([], (a, b) => a..addAll(b))
            .timeout(timeout);
        await control.expect([226, 250]);
        return parse(utf8.decode(bytes, allowMalformed: true))..sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
      throw const FtpException("The server can't list folders.");
    } finally {
      unawaited(control.send('QUIT', const []).catchError((_) => 0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      socket.destroy();
    }
  }

  Future<Socket> _passive(_Control control) async {
    final reply = await control.sendText('PASV', [227]);
    final m = RegExp(r'(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)').firstMatch(reply);
    if (m == null) throw const FtpException('Odd PASV reply.');
    final p = int.parse(m.group(5)!) * 256 + int.parse(m.group(6)!);
    // The control connection's host: servers behind NAT report a private
    // address in PASV.
    return await Socket.connect(host, p, timeout: timeout);
  }

  /// The URL mpv plays a file at [path] from.
  Uri urlOf(String path) => Uri(
    scheme: 'ftp',
    userInfo: user.isEmpty
        ? null
        : '${Uri.encodeComponent(user)}:${Uri.encodeComponent(password)}',
    host: host,
    port: port == 21 ? null : port,
    path: path,
  );
}

/// The control connection: one reply per command, multi-line aware.
class _Control {
  new(Socket socket) : _socket = socket {
    _sub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
  }

  final Socket _socket;
  late final StreamSubscription<String> _sub;
  final _replies = <(int, String)>[];
  final _waiting = <Completer<(int, String)>>[];
  final _pending = StringBuffer();
  int? _multi;

  void _onLine(String line) {
    final code = line.length >= 3 ? int.tryParse(line.substring(0, 3)) : null;
    if (_multi != null) {
      _pending.writeln(line);
      if (code == _multi && line.length > 3 && line[3] == ' ') {
        _deliver((_multi!, _pending.toString()));
        _multi = null;
      }
      return;
    }
    if (code == null) return;
    if (line.length > 3 && line[3] == '-') {
      _multi = code;
      _pending
        ..clear()
        ..writeln(line);
      return;
    }
    _deliver((code, line));
  }

  void _deliver((int, String) reply) {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete(reply);
    } else {
      _replies.add(reply);
    }
  }

  Future<(int, String)> _next() {
    if (_replies.isNotEmpty) return Future.value(_replies.removeAt(0));
    final c = Completer<(int, String)>();
    _waiting.add(c);
    return c.future.timeout(FtpClient.timeout);
  }

  Future<int> expect(List<int> ok) async {
    final (code, text) = await _next();
    if (ok.isNotEmpty && !ok.contains(code)) {
      throw FtpException(code == 530 ? 'Wrong user name or password.' : text);
    }
    return code;
  }

  Future<int> send(String command, List<int> ok) async {
    _socket.write('$command\r\n');
    if (ok.isEmpty) return 0;
    return await expect(ok);
  }

  Future<String> sendText(String command, List<int> ok) async {
    _socket.write('$command\r\n');
    final (code, text) = await _next();
    if (!ok.contains(code)) throw FtpException(text);
    return text;
  }

  Future<void> close() => _sub.cancel();
}
