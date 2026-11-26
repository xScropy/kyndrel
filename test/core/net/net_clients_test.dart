import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/net/dlna_server.dart';
import 'package:kyndrel/core/net/ftp_client.dart';

/// Task 8.7: listing FTP folders and DLNA media servers.
void main() {
  group('FTP', () {
    test('MLSD and Unix LIST replies', () {
      final mlsd = parseMlsd(
        'type=cdir;modify=20260101; .\r\n'
        'type=dir;modify=20260101; Films\r\n'
        'type=file;size=1048576;modify=20260101; clip.mkv\r\n',
      );
      expect(mlsd.map((e) => (e.name, e.isFolder, e.size)), [
        ('Films', true, null),
        ('clip.mkv', false, 1048576),
      ]);
      final list = parseUnixList(
        [
          'drwxr-xr-x  2 ftp ftp     4096 Jan 01 10:00 Films',
          '-rw-r--r--  1 ftp ftp  1048576 Jan 01 10:00 my clip.mkv',
          'lrwxrwxrwx  1 ftp ftp       10 Jan 01 10:00 latest -> Films',
        ].join('\n'),
      );
      expect(list.map((e) => (e.name, e.isFolder)), [
        ('Films', true),
        ('my clip.mkv', false),
        ('latest', false),
      ]);
    });

    test('lists a folder from a real (tiny) server, passive mode', () async {
      final server = await _TinyFtp.start(
        listing: 'type=dir; Films\r\ntype=file;size=12; a.mkv\r\n',
      );
      addTearDown(server.close);
      final ftp = FtpClient(
        host: '127.0.0.1',
        port: server.port,
        user: 'me',
        password: 'secret',
      );
      final entries = await ftp.list('/videos');
      expect(entries.map((e) => e.name), ['Films', 'a.mkv']);
      expect(
        server.commands,
        containsAllInOrder([
          'USER me',
          'PASS secret',
          'TYPE I',
          'PASV',
          'MLSD /videos',
        ]),
      );
      expect(
        ftp.urlOf('/videos/a b.mkv').toString(),
        'ftp://me:secret@127.0.0.1:${server.port}/videos/a%20b.mkv',
      );
    });

    test('a wrong password says so', () async {
      final server = await _TinyFtp.start(listing: '', acceptPassword: false);
      addTearDown(server.close);
      final ftp = FtpClient(host: '127.0.0.1', port: server.port, user: 'me');
      expect(
        () => ftp.list('/'),
        throwsA(
          isA<FtpException>().having(
            (e) => e.message,
            'message',
            contains('password'),
          ),
        ),
      );
    });
  });

  group('DLNA media servers', () {
    test('SSDP replies and device descriptions', () {
      final loc = ssdpLocation(
        'HTTP/1.1 200 OK\r\nST: urn:schemas-upnp-org:device:MediaServer:1\r\n'
            'LOCATION: http://192.168.1.5:8200/rootDesc.xml\r\n\r\n',
        'MediaServer',
      );
      expect(loc, Uri.parse('http://192.168.1.5:8200/rootDesc.xml'));
      expect(
        ssdpLocation(
          'HTTP/1.1 200 OK\r\nST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
              'LOCATION: http://x/\r\n',
          'MediaServer',
        ),
        isNull,
      );
      final server = parseServerDescription(
        loc!,
        '<root><device><friendlyName>NAS</friendlyName><UDN>uuid:1</UDN>'
        '<serviceList><service>'
        '<serviceType>urn:schemas-upnp-org:service:ContentDirectory:1'
        '</serviceType><controlURL>/ctl/ContentDir</controlURL>'
        '</service></serviceList></device></root>',
      );
      expect(server?.name, 'NAS');
      expect(
        server?.control,
        Uri.parse('http://192.168.1.5:8200/ctl/ContentDir'),
      );
    });

    test('DIDL-Lite: folders, videos with their stream URLs', () {
      final entries = parseDidl(
        [
          '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" ',
          'xmlns:dc="http://purl.org/dc/elements/1.1/" ',
          'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">',
          '<container id="64" parentID="0"><dc:title>Films</dc:title>',
          '<upnp:class>object.container.storageFolder</upnp:class>',
          '</container>',
          r'<item id="64$1" parentID="64"><dc:title>Heist</dc:title>',
          '<upnp:class>object.item.videoItem</upnp:class>',
          '<res duration="1:30:00.000" size="1500">',
          'http://nas/MediaItems/1.mkv</res></item>',
          r'<item id="64$2"><dc:title>cover</dc:title>',
          '<upnp:class>object.item.imageItem</upnp:class>',
          '<res>http://nas/1.jpg</res></item>',
          '</DIDL-Lite>',
        ].join(),
      );
      expect(entries.map((e) => (e.title, e.isFolder)), [
        ('Films', true),
        ('Heist', false),
      ]);
      expect(entries[1].url, Uri.parse('http://nas/MediaItems/1.mkv'));
      expect(entries[1].duration, const Duration(minutes: 90));
      expect(entries[1].size, 1500);
    });
  });
}

/// Just enough FTP to answer a listing: a control port and one passive
/// data connection per transfer.
class _TinyFtp {
  new _(this._server, this.listing, {required this.acceptPassword});

  static Future<_TinyFtp> start({
    required String listing,
    bool acceptPassword = true,
  }) async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final ftp = _TinyFtp._(s, listing, acceptPassword: acceptPassword);
    s.listen(ftp._serve);
    return ftp;
  }

  final ServerSocket _server;
  final String listing;
  final bool acceptPassword;
  final commands = <String>[];
  ServerSocket? _data;

  int get port => _server.port;

  Future<void> _serve(Socket c) async {
    c.write('220 tiny\r\n');
    await for (final line
        in c
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      commands.add(line);
      final cmd = line.split(' ').first;
      switch (cmd) {
        case 'USER':
          c.write('331 password please\r\n');
        case 'PASS':
          c.write(acceptPassword ? '230 ok\r\n' : '530 Login incorrect\r\n');
        case 'TYPE':
          c.write('200 ok\r\n');
        case 'PASV':
          _data = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
          final p = _data!.port;
          c.write(
            '227 Entering Passive Mode (127,0,0,1,${p ~/ 256},${p % 256})\r\n',
          );
        case 'MLSD':
          c.write('150 here\r\n');
          final d = await _data!.first;
          d.write(listing);
          await d.close();
          await _data!.close();
          c.write('226 done\r\n');
        case 'QUIT':
          c.write('221 bye\r\n');
          await c.close();
          return;
        default:
          c.write('502 no\r\n');
      }
    }
  }

  Future<void> close() async {
    await _data?.close();
    await _server.close();
  }
}
