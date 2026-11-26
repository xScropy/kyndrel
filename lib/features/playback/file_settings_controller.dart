import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/video_view_settings.dart';
import 'package:kyndrel/core/storage/file_settings_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';

/// Each file remembers its audio and subtitle tracks, speed, delays, fit,
/// zoom and rotation (task 8.8, like SMPlayer and Next Player).
///
/// When a file opens with saved settings, they are applied once its tracks
/// are known; afterwards, changes are saved a moment after they happen.
/// Off in incognito and when the setting is off.
class FileSettingsController extends Notifier<void> {
  /// How long a change waits before it is saved (sliders move a lot).
  static const saveDelay = Duration(seconds: 1);

  String? _source;

  /// The source whose saved settings were applied (or found missing):
  /// changes are only saved after that, so the defaults of a file still
  /// opening never overwrite what it had.
  String? _ready;
  PerFileSettings? _pending;
  Timer? _save;
  PlaybackState _state = PlaybackState.initial;
  TrackState _tracks = TrackState.empty;

  /// Taken when the controller starts: dispose may not read providers.
  late FileSettingsRepository _repo;

  bool get _enabled {
    final s = ref.read(settingsProvider);
    return s.rememberFileSettings && !s.incognito;
  }

  @override
  void build() {
    final service = ref.watch(playerServiceProvider);
    _repo = ref.watch(fileSettingsRepositoryProvider);
    final states = service.states.listen(_onState);
    final tracks = service.trackStates.listen(_onTracks);
    ref
      ..listen(videoViewProvider, (_, _) => _changed())
      ..onDispose(() {
        _write();
        unawaited(states.cancel());
        unawaited(tracks.cancel());
      });
  }

  void _onState(PlaybackState s) {
    final previous = _state;
    _state = s;
    if (s.source != _source) {
      _write();
      _source = s.source;
      _ready = null;
      _pending = null;
    }
    if (s.rate != previous.rate) _changed();
  }

  void _onTracks(TrackState t) {
    final previous = _tracks;
    _tracks = t;
    final source = _source;
    if (source == null) return;
    // Tracks arrived for a file not restored yet.
    if (_ready != source && (t.audio.isNotEmpty || t.video.isNotEmpty)) {
      _ready = source;
      unawaited(_restore(source));
      return;
    }
    if (t.audioId != previous.audioId ||
        t.subtitleId != previous.subtitleId ||
        t.secondarySubtitleId != previous.secondarySubtitleId ||
        t.subtitleDelay != previous.subtitleDelay ||
        t.audioDelay != previous.audioDelay) {
      _changed();
    }
  }

  Future<void> _restore(String source) async {
    if (!_enabled) return;
    final saved = await _repo.get(source);
    if (saved == null || _source != source) return;
    final service = ref.read(playerServiceProvider);
    final t = _tracks;
    if (saved.audioId != null && t.audio.any((a) => a.id == saved.audioId)) {
      await service.selectAudioTrack(saved.audioId!);
    }
    final sid = saved.subtitleId;
    if (sid == PerFileSettings.noSubtitles) {
      await service.selectSubtitle(null);
    } else if (sid != null && t.subtitles.any((s) => s.id == sid)) {
      await service.selectSubtitle(sid);
    }
    final sid2 = saved.secondarySubtitleId;
    if (sid2 != null && t.subtitles.any((s) => s.id == sid2)) {
      await service.selectSecondarySubtitle(sid2);
    }
    if (saved.subtitleDelay != Duration.zero) {
      await service.setSubtitleDelay(saved.subtitleDelay);
    }
    if (saved.audioDelay != Duration.zero) {
      await service.setAudioDelay(saved.audioDelay);
    }
    if (saved.rate != 1) await service.setRate(saved.rate);
    final view = ref.read(videoViewProvider.notifier);
    final fit = VideoFit.values.where((f) => f.name == saved.fit).firstOrNull;
    if (fit != null) await view.setFit(fit);
    view.setZoom(saved.zoom);
    if (saved.rotation != 0) await view.setRotation(saved.rotation);
  }

  PerFileSettings _current() {
    final t = _tracks;
    final v = ref.read(videoViewProvider);
    return PerFileSettings(
      audioId: t.audioId,
      subtitleId: t.subtitleId ?? PerFileSettings.noSubtitles,
      secondarySubtitleId: t.secondarySubtitleId,
      rate: _state.rate,
      subtitleDelay: t.subtitleDelay,
      audioDelay: t.audioDelay,
      fit: v.fit.name,
      zoom: v.zoom,
      rotation: v.rotation,
    );
  }

  void _changed() {
    final source = _source;
    if (source == null || _ready != source || !_enabled) return;
    _pending = _current();
    _save?.cancel();
    _save = Timer(saveDelay, _write);
  }

  /// Saves what [_changed] queued (it only queues when saving is allowed,
  /// so this reads no providers and is safe while disposing).
  void _write() {
    _save?.cancel();
    _save = null;
    final source = _source;
    final pending = _pending;
    _pending = null;
    if (source != null && pending != null) {
      unawaited(_repo.save(source, pending));
    }
  }
}

final fileSettingsControllerProvider =
    NotifierProvider<FileSettingsController, void>(FileSettingsController.new);
