import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/platform/media_session.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/utils/media_title.dart';

/// The OS media session; replaced in `main.dart` with the platform one.
final mediaSessionProvider = Provider<MediaSession>(
  (ref) => const NoopMediaSession(),
);

/// Keeps the OS media overlay (SMTC, MPRIS, Now Playing) in step with
/// playback, and turns its buttons and media keys into player commands
/// (task 4.8).
final mediaSessionSyncProvider = Provider<void>((ref) {
  final session = ref.watch(mediaSessionProvider);
  final service = ref.watch(playerServiceProvider);
  MediaSessionState? last;
  var lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  MediaSessionState build(PlaybackState s) {
    final source = s.source;
    final queue = ref.read(playlistProvider);
    if (source == null) return const MediaSessionState();
    final details = ref.read(mediaDetailsProvider(source)).value;
    final parsed = parseMediaTitle(source);
    return MediaSessionState(
      title: details?.title ?? parsed.title,
      subtitle:
          details?.subtitle ??
          [
            ?parsed.episode,
            if (parsed.year != null) '${parsed.year}',
          ].join(' · '),
      artUrl: details?.posterUrl,
      playing: s.isPlaying,
      position: s.position,
      duration: s.duration,
      canNext: queue.hasNext,
      canPrevious: queue.items.length > 1,
      volume: (s.volume / 100).clamp(0, 1),
    );
  }

  final sub = service.states.listen((s) {
    final next = build(s);
    final now = DateTime.now();
    final same =
        last != null &&
        last!.title == next.title &&
        last!.playing == next.playing &&
        last!.duration == next.duration &&
        last!.canNext == next.canNext &&
        (next.position - last!.position).abs() < const Duration(seconds: 2);
    // Position alone is pushed at most once a second.
    if (same && now.difference(lastPush) < const Duration(seconds: 1)) return;
    last = next;
    lastPush = now;
    unawaited(session.update(next));
  });

  final commands = session.commands.listen((c) {
    final playlist = ref.read(playlistProvider.notifier);
    unawaited(switch (c) {
      PlayCommand() => service.play(),
      PauseCommand() || StopCommand() => service.pause(),
      PlayPauseCommand() => service.playOrPause(),
      NextCommand() => playlist.next(),
      PreviousCommand() => playlist.previous(),
      SeekToCommand(:final position) => service.seek(position),
      SeekByCommand(:final offset) => service.seekBy(offset),
      SetVolumeCommand(:final volume) => service.setVolume(volume * 100),
      RaiseCommand() => Future<void>.value(),
    });
  });

  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(commands.cancel());
  });
});
