import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/media_scanner.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/media_index.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/media_title.dart';

/// The song playing now (task 7.6).
@immutable
class NowPlaying {
  const new({
    required this.source,
    required this.title,
    this.artist,
    this.album,
    this.cover,
  });

  final String source;
  final String title;
  final String? artist;
  final String? album;

  /// A picture file: the song's cover art.
  final String? cover;

  NowPlaying withCover(String? cover) => NowPlaying(
    source: source,
    title: title,
    artist: artist,
    album: album,
    cover: cover,
  );
}

/// Music playing (a file with sound and at most a cover picture): its
/// tags and cover; null for videos and when idle. Also runs the level
/// meter for the waves while music plays.
class NowPlayingController extends Notifier<NowPlaying?> {
  String? _for;

  @override
  NowPlaying? build() {
    final service = ref.watch(playerServiceProvider);
    final waves = ref.watch(settingsProvider.select((s) => s.musicWaves));
    // Rebuilt (a setting changed): the current song loads again.
    _for = null;
    // A direct subscription (it also delivers the current tracks at once):
    // provider listeners pause while nothing watches this provider.
    final sub = service.trackStates.listen((t) {
      final source = service.state.source;
      final music = source != null && t.isAudioOnly;
      unawaited(service.setLevelMeter(enabled: waves && music));
      if (!music) {
        if (_for != null) {
          _for = null;
          state = null;
          ref.read(musicMinimizedProvider.notifier).expand();
        }
        return;
      }
      if (source == _for) return;
      _for = source;
      unawaited(_load(source));
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return null;
  }

  Future<void> _load(String source) async {
    final service = ref.read(playerServiceProvider);
    final db = ref.read(databaseProvider);
    final tags = await service.readTags();
    LibraryItem? item;
    try {
      item = await (db.select(
        db.libraryItems,
      )..where((t) => t.uri.equals(source))).getSingleOrNull();
    } on Object {
      item = null;
    }
    if (_for != source) return;
    var now = NowPlaying(
      source: source,
      title: tags.title ?? item?.title ?? parseMediaTitle(source).title,
      artist: tags.artist ?? item?.artist,
      album: tags.album ?? item?.album,
      cover: item?.thumbnailPath,
    );
    state = now;
    if (now.cover != null) return;
    // Not in the library (yet): ask for the cover directly.
    try {
      final cover = await ref
          .read(mediaProberProvider)
          .thumbnail(source, MediaKind.audio, duration: service.state.duration);
      if (_for != source || cover == null) return;
      now = now.withCover(cover);
      state = now;
    } on Object {
      // No cover: the disc shows its plain label.
    }
  }
}

final nowPlayingProvider = NotifierProvider<NowPlayingController, NowPlaying?>(
  NowPlayingController.new,
);

/// The music player shrunk to a bar while browsing the library.
class MusicMinimizedController extends Notifier<bool> {
  @override
  bool build() => false;

  void minimize() => state = true;

  void expand() => state = false;
}

final musicMinimizedProvider = NotifierProvider<MusicMinimizedController, bool>(
  MusicMinimizedController.new,
);
