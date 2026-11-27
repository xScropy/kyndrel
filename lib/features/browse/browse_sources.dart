import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/net/dlna_server.dart';
import 'package:kyndrel/core/net/ftp_client.dart';
import 'package:kyndrel/core/net/webdav.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';
import 'package:path/path.dart' as p;

/// Kinds of servers Browse can save (task 8.7).
enum ServerKind {
  webdav,
  ftp,

  /// Windows shares and SFTP: opened by address (mpv plays them when its
  /// build has the protocol); Kyndrel can't list them.
  smb,
  sftp;

  bool get listable => this == webdav || this == ftp;
}

/// A network server the user added.
@immutable
class SavedServer {
  const new({
    required this.kind,
    required this.name,
    required this.address,
    this.user = '',
  });

  factory fromJson(Map<String, Object?> j) => SavedServer(
    kind: ServerKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => ServerKind.webdav,
    ),
    name: j['name'] as String? ?? '',
    address: j['address'] as String? ?? '',
    user: j['user'] as String? ?? '',
  );

  final ServerKind kind;
  final String name;

  /// `https://host/dav/`, `ftp://host/`, `smb://host/share/`.
  final String address;
  final String user;

  Uri get uri => Uri.parse(address);
  String get key => '${kind.name}|$address|$user';

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'name': name,
    'address': address,
    'user': user,
  };

  @override
  bool operator ==(Object other) => other is SavedServer && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Somewhere Browse can list.
@immutable
sealed class BrowseLocation {
  const new();

  /// The breadcrumb label.
  String get label;
}

class LocalLocation extends BrowseLocation {
  const new(this.path, {this.title});
  final String path;
  final String? title;

  @override
  String get label =>
      title ?? (p.basename(path).isEmpty ? path : p.basename(path));

  @override
  bool operator ==(Object other) =>
      other is LocalLocation && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class ServerLocation extends BrowseLocation {
  const new(this.server, this.path, {this.title});
  final SavedServer server;

  /// Path below the server's address, starting with `/`.
  final String path;
  final String? title;

  @override
  String get label =>
      title ?? (path == '/' ? server.name : p.url.basename(path));

  @override
  bool operator ==(Object other) =>
      other is ServerLocation && other.server == server && other.path == path;

  @override
  int get hashCode => Object.hash(server, path);
}

class DlnaLocation extends BrowseLocation {
  const new(this.server, this.objectId, this.title);
  final DlnaServer server;
  final String objectId;
  final String title;

  @override
  String get label => title;

  @override
  bool operator ==(Object other) =>
      other is DlnaLocation &&
      other.server.id == server.id &&
      other.objectId == objectId;

  @override
  int get hashCode => Object.hash(server.id, objectId);
}

/// A folder or playable file in a listing.
@immutable
class BrowseEntry {
  const new({
    required this.name,
    required this.isFolder,
    this.location,
    this.play,
    this.size,
    this.headers = const [],
  });

  final String name;
  final bool isFolder;

  /// Where a folder leads.
  final BrowseLocation? location;

  /// What mpv opens for a file.
  final String? play;
  final int? size;

  /// HTTP login headers for [play] (WebDAV).
  final List<String> headers;
}

/// Thrown when a server needs a password Browse doesn't have yet.
class NeedsPassword implements Exception {
  const new(this.server);
  final SavedServer server;
}

/// Lists folders on this device and on network servers.
class BrowseService {
  new({DlnaBrowser? dlna}) : _dlna = dlna ?? DlnaBrowser();

  final DlnaBrowser _dlna;

  /// Passwords typed this session, by server key. Never written to disk.
  final passwords = <String, String>{};

  static bool isPlayable(String name) => PlaylistController.mediaExtensions
      .contains(p.extension(name).toLowerCase());

  static int _order(BrowseEntry a, BrowseEntry b) {
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    return compareNatural(a.name, b.name);
  }

  Future<List<BrowseEntry>> list(BrowseLocation location) async {
    final out = switch (location) {
      LocalLocation(:final path) => await _local(path),
      ServerLocation(:final server, :final path) => await _server(server, path),
      DlnaLocation(:final server, :final objectId) => await _dlnaList(
        server,
        objectId,
      ),
    };
    return out..sort(_order);
  }

  Future<List<BrowseEntry>> _local(String path) async {
    final out = <BrowseEntry>[];
    await for (final e in Directory(path).list(followLinks: false)) {
      final name = p.basename(e.path);
      if (name.startsWith('.')) continue;
      if (e is Directory) {
        out.add(
          BrowseEntry(
            name: name,
            isFolder: true,
            location: LocalLocation(e.path),
          ),
        );
      } else if (e is File && isPlayable(name)) {
        out.add(BrowseEntry(name: name, isFolder: false, play: e.path));
      }
    }
    return out;
  }

  Future<List<BrowseEntry>> _server(SavedServer s, String path) async {
    final password = passwords[s.key];
    if (s.user.isNotEmpty && password == null) throw NeedsPassword(s);
    switch (s.kind) {
      case ServerKind.webdav:
        final base = s.uri;
        final folder = base.replace(
          path: p.url.join(
            base.path.isEmpty ? '/' : base.path,
            path.substring(1),
          ),
        );
        final dav = WebDavClient(user: s.user, password: password ?? '');
        try {
          final entries = await dav.list(
            folder.path.endsWith('/')
                ? folder
                : folder.replace(path: '${folder.path}/'),
          );
          final rel = base.path.endsWith('/') ? base.path : '${base.path}/';
          return [
            for (final e in entries)
              if (e.isFolder)
                BrowseEntry(
                  name: e.name,
                  isFolder: true,
                  location: ServerLocation(
                    s,
                    '/${Uri.decodeComponent(e.url.path).replaceFirst(Uri.decodeComponent(rel), '')}',
                    title: e.name,
                  ),
                )
              else if (isPlayable(e.name))
                BrowseEntry(
                  name: e.name,
                  isFolder: false,
                  play: e.url.toString(),
                  size: e.size,
                  headers: dav.headers,
                ),
          ];
        } finally {
          dav.close();
        }
      case ServerKind.ftp:
        final u = s.uri;
        final ftp = FtpClient(
          host: u.host,
          port: u.hasPort ? u.port : 21,
          user: s.user,
          password: password ?? '',
        );
        final dir = p.url.join(
          u.path.isEmpty ? '/' : u.path,
          path.substring(1),
        );
        final entries = await ftp.list(dir);
        return [
          for (final e in entries)
            if (e.isFolder)
              BrowseEntry(
                name: e.name,
                isFolder: true,
                location: ServerLocation(
                  s,
                  p.url.join(path, e.name),
                  title: e.name,
                ),
              )
            else if (isPlayable(e.name))
              BrowseEntry(
                name: e.name,
                isFolder: false,
                play: ftp.urlOf(p.url.join(dir, e.name)).toString(),
                size: e.size,
              ),
        ];
      case ServerKind.smb:
      case ServerKind.sftp:
        throw const BrowseNotListable();
    }
  }

  Future<List<BrowseEntry>> _dlnaList(DlnaServer server, String id) async {
    final entries = await _dlna.browse(server, id);
    return [
      for (final e in entries)
        BrowseEntry(
          name: e.title,
          isFolder: e.isFolder,
          location: e.isFolder ? DlnaLocation(server, e.id, e.title) : null,
          play: e.url?.toString(),
          size: e.size,
        ),
    ];
  }

  /// Media servers on this network.
  Future<List<DlnaServer>> discover() => _dlna.discover();
}

/// SMB and SFTP servers open by address only.
class BrowseNotListable implements Exception {
  const new();
}

final browseServiceProvider = Provider<BrowseService>((ref) => BrowseService());

/// The user's saved servers.
List<SavedServer> savedServers(AppSettings s) => [
  for (final j in s.browseServers)
    try_(() => SavedServer.fromJson(jsonDecode(j) as Map<String, Object?>)),
].whereType<SavedServer>().toList();

T? try_<T>(T Function() f) {
  try {
    return f();
  } on Object {
    return null;
  }
}

/// Where this device keeps files: home, the library folders, drives and
/// mounted disks (task 8.7).
///
/// Never on the UI thread, and each check gives up after [rootTimeout]: on
/// Windows an empty card reader, a DVD drive or a disconnected network
/// drive can take many seconds to answer, which froze Browse.
Future<List<LocalLocation>> localRoots({
  List<String> libraryFolders = const [],
  Map<String, String>? environment,
}) async {
  final env = environment ?? Platform.environment;
  final wanted = <(String, String?)>[];
  void want(String path, [String? title]) {
    if (!wanted.any((w) => w.$1 == path)) wanted.add((path, title));
  }

  Future<void> wantChildren(String base, {Set<String> skip = const {}}) async {
    try {
      final children = await Directory(base)
          .list(followLinks: false)
          .where((d) => d is Directory && !skip.contains(p.basename(d.path)))
          .toList()
          .timeout(rootTimeout);
      for (final d in children..sort((a, b) => a.path.compareTo(b.path))) {
        want(d.path, p.basename(d.path));
      }
    } on Object {
      // Not there, not readable or too slow: skip it.
    }
  }

  if (Platform.isAndroid) {
    want('/storage/emulated/0', 'Internal storage');
    await wantChildren('/storage', skip: {'emulated', 'self'});
  } else {
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (home != null) want(home, 'Home');
    (libraryFolders.isEmpty
            ? FolderMediaScanner.defaultFolders(environment: env)
            : libraryFolders)
        .forEach(want);
    if (Platform.isWindows) {
      // Only the letters Windows has; never probe all 24.
      final mask = windowsDriveMask();
      for (var i = 2; i < 26; i++) {
        if (mask != null && mask & (1 << i) == 0) continue;
        final c = String.fromCharCode(0x41 + i);
        want('$c:\\', '$c:');
      }
    } else if (Platform.isMacOS) {
      await wantChildren('/Volumes');
    } else {
      final user = env['USER'] ?? '';
      for (final base in ['/media/$user', '/run/media/$user', '/mnt']) {
        await wantChildren(base);
      }
      want('/', '/');
    }
  }
  final present = await Future.wait([
    for (final (path, _) in wanted) _exists(path),
  ]);
  return [
    for (var i = 0; i < wanted.length; i++)
      if (present[i]) LocalLocation(wanted[i].$1, title: wanted[i].$2),
  ];
}

/// How long a drive or folder may take to say it exists.
const rootTimeout = Duration(seconds: 2);

Future<bool> _exists(String path) async {
  try {
    // Async on purpose: the sync call blocks the UI on a slow drive.
    // ignore: avoid_slow_async_io
    final found = Directory(path).exists();
    return await found.timeout(rootTimeout, onTimeout: () => false);
  } on Object {
    return false;
  }
}

/// The drive letters Windows has (bit 0 is A:), or null when unknown.
int? windowsDriveMask() {
  if (!Platform.isWindows) return null;
  try {
    final getLogicalDrives = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<Uint32 Function(), int Function()>('GetLogicalDrives');
    final mask = getLogicalDrives();
    return mask == 0 ? null : mask;
  } on Object {
    return null;
  }
}

/// The places Browse shows, found once per change of the library folders.
final localRootsProvider = FutureProvider<List<LocalLocation>>(
  (ref) => localRoots(
    libraryFolders: ref.watch(settingsProvider.select((s) => s.libraryFolders)),
  ),
);
