import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the OS media overlay shows (task 4.8).
@immutable
class MediaSessionState {
  const new({
    this.title,
    this.subtitle,
    this.artUrl,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.canNext = false,
    this.canPrevious = false,
    this.volume = 1,
  });

  /// Null when nothing is open.
  final String? title;
  final String? subtitle;
  final String? artUrl;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool canNext;
  final bool canPrevious;

  /// 0–1 (the OS has no idea about 500 %).
  final double volume;

  Map<String, Object?> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'artUrl': artUrl,
    'playing': playing,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'canNext': canNext,
    'canPrevious': canPrevious,
    'volume': volume,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaSessionState && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// A command from media keys or the OS overlay.
sealed class MediaCommand {
  const new();
}

class PlayCommand extends MediaCommand {
  const new();
}

class PauseCommand extends MediaCommand {
  const new();
}

class PlayPauseCommand extends MediaCommand {
  const new();
}

class StopCommand extends MediaCommand {
  const new();
}

class NextCommand extends MediaCommand {
  const new();
}

class PreviousCommand extends MediaCommand {
  const new();
}

class SeekToCommand extends MediaCommand {
  const new(this.position);
  final Duration position;
}

class SeekByCommand extends MediaCommand {
  const new(this.offset);
  final Duration offset;
}

class SetVolumeCommand extends MediaCommand {
  const new(this.volume);
  final double volume;
}

class RaiseCommand extends MediaCommand {
  const new();
}

/// The OS media session: Windows SMTC, Linux MPRIS, macOS Now Playing,
/// Android's MediaSession.
abstract interface class MediaSession {
  Stream<MediaCommand> get commands;
  Future<void> update(MediaSessionState state);
  Future<void> dispose();
}

class NoopMediaSession implements MediaSession {
  const new();

  @override
  Stream<MediaCommand> get commands => const Stream.empty();

  @override
  Future<void> update(MediaSessionState state) async {}

  @override
  Future<void> dispose() async {}
}

/// Windows (SMTC) and macOS (Now Playing) through the runner's native code
/// on the `kyndrel/media_session` channel.
class ChannelMediaSession implements MediaSession {
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('kyndrel/media_session') {
    _channel.setMethodCallHandler((call) async {
      final a = call.arguments;
      final cmd = switch (call.method) {
        'play' => const PlayCommand(),
        'pause' => const PauseCommand(),
        'playPause' => const PlayPauseCommand(),
        'stop' => const StopCommand(),
        'next' => const NextCommand(),
        'previous' => const PreviousCommand(),
        'seekTo' when a is int => SeekToCommand(Duration(milliseconds: a)),
        'seekBy' when a is int => SeekByCommand(Duration(milliseconds: a)),
        _ => null,
      };
      if (cmd != null) _commands.add(cmd);
    });
  }

  final MethodChannel _channel;
  final _commands = StreamController<MediaCommand>.broadcast();

  @override
  Stream<MediaCommand> get commands => _commands.stream;

  @override
  Future<void> update(MediaSessionState state) async {
    try {
      await _channel.invokeMethod<void>('update', state.toMap());
    } on MissingPluginException {
      // Platform without the native side.
    } on PlatformException {
      // OS refused; ignore.
    }
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _commands.close();
  }
}

/// The right session for this OS. Linux uses MPRIS (see mpris.dart);
/// Android has a MediaSession and notification in MainActivity (6.6).
MediaSession platformMediaSession() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isAndroid) {
    return ChannelMediaSession();
  }
  return const NoopMediaSession();
}
