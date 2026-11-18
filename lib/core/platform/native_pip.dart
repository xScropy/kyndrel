import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system's picture-in-picture (Android, task 6.6): the whole app
/// shrinks into a floating window that Android draws and moves.
abstract interface class NativePip {
  Future<bool> get supported;

  /// Enters PiP now; false when the system refused.
  Future<bool> enter({required double aspect});

  /// What PiP looks like when it starts, and whether going Home while a
  /// video plays enters it on its own.
  Future<void> configure({
    required bool auto,
    required double aspect,
    required bool playing,
  });

  /// True on entering PiP, false on leaving it.
  Stream<bool> get changes;
}

class AndroidNativePip implements NativePip {
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('kyndrel/pip') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && call.arguments is bool) {
        _changes.add(call.arguments as bool);
      }
    });
  }

  final MethodChannel _channel;
  final _changes = StreamController<bool>.broadcast();

  @override
  Future<bool> get supported async =>
      await _channel.invokeMethod<bool>('supported') ?? false;

  @override
  Future<bool> enter({required double aspect}) async =>
      await _channel.invokeMethod<bool>('enter', {'aspect': aspect}) ?? false;

  @override
  Future<void> configure({
    required bool auto,
    required double aspect,
    required bool playing,
  }) => _channel.invokeMethod<void>('configure', {
    'auto': auto,
    'aspect': aspect,
    'playing': playing,
  });

  @override
  Stream<bool> get changes => _changes.stream;
}

/// Null where PiP is the in-window kind (desktop).
final nativePipProvider = Provider<NativePip?>(
  (ref) => Platform.isAndroid ? AndroidNativePip() : null,
);
