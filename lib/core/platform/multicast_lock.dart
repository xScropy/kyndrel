import 'dart:io';

import 'package:flutter/services.dart';

/// Android drops multicast packets to save battery unless an app holds a
/// lock, so DLNA and Chromecast discovery would never hear a reply
/// (task 6.6). A no-op elsewhere.
abstract final class MulticastLock {
  static const _channel = MethodChannel('kyndrel/multicast');

  /// Runs [body] with the lock held.
  static Future<T> hold<T>(Future<T> Function() body) async {
    if (!Platform.isAndroid) return await body();
    try {
      await _channel.invokeMethod<void>('acquire');
    } on PlatformException {
      // Wi-Fi off or not allowed: try anyway.
    }
    try {
      return await body();
    } finally {
      try {
        await _channel.invokeMethod<void>('release');
      } on PlatformException {
        // Ignore.
      }
    }
  }
}
