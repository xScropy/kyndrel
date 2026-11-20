import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps library folders readable on macOS, where the app is sandboxed: a
/// folder picked in the open panel is readable only until the app quits,
/// unless a security-scoped bookmark is saved (task 7.3; `kyndrel/bookmarks`
/// in macos/Runner/FolderBookmarks.swift). Elsewhere nothing is needed.
abstract final class FolderAccess {
  static const _channel = MethodChannel('kyndrel/bookmarks');

  /// A bookmark to save with the settings, or null where none is needed
  /// or it couldn't be made.
  static Future<String?> bookmark(String path) async {
    if (!Platform.isMacOS) return null;
    try {
      return await _channel.invokeMethod<String>('create', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens access to the saved folders again (call before scanning).
  static Future<void> restore(List<String> bookmarks) async {
    if (!Platform.isMacOS) return;
    for (final data in bookmarks) {
      try {
        await _channel.invokeMethod<String>('resolve', {'data': data});
      } on PlatformException {
        // Moved or deleted: the scan simply finds nothing there.
      } on MissingPluginException {
        return;
      }
    }
  }
}
