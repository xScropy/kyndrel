import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/utils/media_title.dart';

/// A picked or shared file: a `content://` URI on Android, plus the name
/// the user knows it by (the URI itself is often just a number).
@immutable
class DeviceFile {
  const new(this.uri, this.name);

  factory fromMap(Map<Object?, Object?> m) =>
      DeviceFile(m['uri']! as String, (m['name'] as String?) ?? '');

  final String uri;
  final String name;

  /// Lets titles, history and the top bar show [name] for [uri].
  void remember() {
    if (name.isNotEmpty) rememberDisplayName(uri, name);
  }
}

/// A video from the phone's media library (MediaStore).
@immutable
class DeviceVideo {
  const new({
    required this.file,
    required this.folder,
    required this.duration,
    required this.size,
    required this.added,
  });

  factory fromMap(Map<Object?, Object?> m) => DeviceVideo(
    file: DeviceFile.fromMap(m),
    folder: (m['folder'] as String?) ?? '',
    duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
    size: (m['size'] as num?)?.toInt() ?? 0,
    added: DateTime.fromMillisecondsSinceEpoch(
      ((m['addedS'] as num?)?.toInt() ?? 0) * 1000,
    ),
  );

  final DeviceFile file;

  /// MediaStore bucket name, e.g. `Camera`, `Download`, `WhatsApp Video`.
  final String folder;
  final Duration duration;
  final int size;
  final DateTime added;
}

/// The phone's own file and media access (task 6.2).
abstract interface class DeviceMedia {
  /// The system document picker (no copy: big videos play in place).
  Future<List<DeviceFile>> pick({bool multiple = false});

  /// Any file, copied to the cache under its own name; its path, or null
  /// when cancelled. For subtitles: mpv needs a path with the extension
  /// (task 7.1).
  Future<String?> pickFileCopy();

  /// Asks for the "videos" permission when needed; true when granted.
  Future<bool> requestVideoAccess();

  /// Every video in the media library, newest first.
  Future<List<DeviceVideo>> videos();
}

/// [DeviceMedia] over the `kyndrel/android_media` channel (MainActivity.kt).
class AndroidDeviceMedia implements DeviceMedia {
  const new();

  static const _channel = MethodChannel('kyndrel/android_media');

  @override
  Future<List<DeviceFile>> pick({bool multiple = false}) async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'pick',
      {'multiple': multiple},
    );
    return [
      for (final m in list ?? const <Map<Object?, Object?>>[])
        DeviceFile.fromMap(m),
    ];
  }

  @override
  Future<String?> pickFileCopy() => _channel.invokeMethod<String>('pickCopy');

  @override
  Future<bool> requestVideoAccess() async =>
      await _channel.invokeMethod<bool>('requestVideoAccess') ?? false;

  @override
  Future<List<DeviceVideo>> videos() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'videos',
    );
    return [
      for (final m in list ?? const <Map<Object?, Object?>>[])
        DeviceVideo.fromMap(m),
    ];
  }
}

/// Null where the desktop file picker and folders are used instead.
final deviceMediaProvider = Provider<DeviceMedia?>(
  (ref) => Platform.isAndroid ? const AndroidDeviceMedia() : null,
);
