import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A release version like `1.2.0` or `1.2.0-beta.1` (a leading `v` is
/// ignored). Pre-releases sort before the release they lead to.
@immutable
class AppVersionNumber implements Comparable<AppVersionNumber> {
  const new(this.parts, [this.preRelease = '']);

  static AppVersionNumber? tryParse(String text) {
    final m = RegExp(
      r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$',
    ).firstMatch(text.trim());
    if (m == null) return null;
    return AppVersionNumber([
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3] ?? '0'),
    ], m[4] ?? '');
  }

  final List<int> parts;
  final String preRelease;

  @override
  int compareTo(AppVersionNumber other) {
    for (var i = 0; i < 3; i++) {
      final c = parts[i].compareTo(other.parts[i]);
      if (c != 0) return c;
    }
    if (preRelease == other.preRelease) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    return preRelease.compareTo(other.preRelease);
  }

  bool operator >(AppVersionNumber other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersionNumber && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(parts[0], parts[1], parts[2], preRelease);

  @override
  String toString() =>
      parts.join('.') + (preRelease.isEmpty ? '' : '-$preRelease');
}

/// Which installer fits this machine.
enum UpdatePackage {
  windowsInstaller('-windows-x64-setup.exe'),
  macDmg('.dmg'),
  linuxAppImage('-x86_64.AppImage'),
  linuxDeb('_amd64.deb');

  new(this.suffix);
  final String suffix;

  /// The current platform's package; an AppImage updates to an AppImage.
  static UpdatePackage? current() {
    if (Platform.isWindows) return windowsInstaller;
    if (Platform.isMacOS) return macDmg;
    if (Platform.isLinux) {
      return Platform.environment.containsKey('APPIMAGE')
          ? linuxAppImage
          : linuxDeb;
    }
    return null;
  }
}

@immutable
class UpdateInfo {
  const new({
    required this.version,
    required this.pageUrl,
    this.downloadUrl,
    this.notes = '',
  });

  final AppVersionNumber version;

  /// The release page (notes and every download).
  final Uri pageUrl;

  /// The installer for this platform, when the release has one.
  final Uri? downloadUrl;
  final String notes;
}

class UpdateCheckException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Asks GitHub for the latest published release (task 5.6). Drafts and
/// pre-releases are never offered.
class UpdateChecker {
  new({
    required this.repository,
    required this.currentVersion,
    http.Client? client,
    UpdatePackage? package,
  }) : _http = client ?? http.Client(),
       _package = package ?? UpdatePackage.current();

  /// `owner/name` on GitHub.
  final String repository;
  final String currentVersion;
  final http.Client _http;
  final UpdatePackage? _package;

  /// The newer release, or null when this is the latest.
  Future<UpdateInfo?> check() async {
    final http.Response res;
    try {
      res = await _http
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Kyndrel-update-check',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw UpdateCheckException('Could not reach GitHub ($e).');
    }
    // No published release yet.
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw UpdateCheckException('GitHub answered ${res.statusCode}.');
    }
    final json = (jsonDecode(res.body) as Map).cast<String, Object?>();
    final latest = AppVersionNumber.tryParse(json['tag_name'] as String? ?? '');
    final current = AppVersionNumber.tryParse(currentVersion);
    if (latest == null || current == null || !(latest > current)) return null;

    Uri? download;
    final suffix = _package?.suffix;
    final assets = (json['assets'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    for (final a in assets) {
      final name = a['name'] as String? ?? '';
      if (suffix != null && name.endsWith(suffix)) {
        download = Uri.tryParse(a['browser_download_url'] as String? ?? '');
        break;
      }
    }
    return UpdateInfo(
      version: latest,
      pageUrl: Uri.parse(json['html_url'] as String? ?? ''),
      downloadUrl: download,
      notes: json['body'] as String? ?? '',
    );
  }

  /// Downloads [url] to [file], reporting progress 0..1 (task 5.6: the
  /// Windows installer for a silent update).
  Future<File> download(
    Uri url,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final res = await _http.send(http.Request('GET', url));
    if (res.statusCode != 200) {
      throw UpdateCheckException('Download failed (${res.statusCode}).');
    }
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  void close() => _http.close();
}
