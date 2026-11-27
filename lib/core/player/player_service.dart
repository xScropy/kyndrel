import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_backend.dart';
import 'package:kyndrel/core/player/remote_target.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/core/utils/time_format.dart';

/// The single entry point to the playback engine (PLAN.md §2).
///
/// Turns the backend's raw streams into [PlaybackState] and [TrackState] and
/// exposes the commands the UI needs. Every mpv property it touches is listed
/// in `docs/mpv-properties.md`. UI code reads it through the Riverpod
/// providers in `player_providers.dart`.
class PlayerService {
  new(this.backend) {
    _subscriptions.addAll([
      // Not a sign of loading: media_kit reports playing=true as soon as
      // a file is opened, before mpv has read it.
      backend.playing.listen((v) => _update(_state.copyWith(isPlaying: v))),
      backend.completed.listen(_onCompleted),
      backend.buffering.listen((v) => _update(_state.copyWith(isBuffering: v))),
      backend.position.listen((v) => _update(_state.copyWith(position: v))),
      backend.duration.listen(
        (v) => _update(
          _state.copyWith(
            duration: v,
            isLoaded: v > Duration.zero || _state.isLoaded,
          ),
        ),
      ),
      backend.buffer.listen((v) => _update(_state.copyWith(buffered: v))),
      backend.width.listen(
        (v) => _update(
          _state.copyWith(
            videoWidth: v,
            isLoaded: v != null || _state.isLoaded,
          ),
        ),
      ),
      backend.height.listen((v) => _update(_state.copyWith(videoHeight: v))),
      backend.volume.listen((v) => _update(_state.copyWith(volume: v))),
      backend.rate.listen((v) => _update(_state.copyWith(rate: v))),
      backend.error.listen(_onError),
      backend.log.listen(_onLog),
      backend.tracksChanged.listen((_) {
        unawaited(refreshTracks());
        unawaited(refreshChapters());
      }),
      backend
          .observe('mute')
          .listen((v) => _update(_state.copyWith(isMuted: v == 'yes'))),
      backend
          .observe('aid')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(audioId: () => _id(v))),
          ),
      backend
          .observe('sid')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(subtitleId: () => _id(v))),
          ),
      backend
          .observe('secondary-sid')
          .listen(
            (v) => _updateTracks(
              _tracks.copyWith(secondarySubtitleId: () => _id(v)),
            ),
          ),
      backend
          .observe('sub-delay')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(subtitleDelay: _seconds(v))),
          ),
      backend
          .observe('chapter')
          .listen(
            (v) => _updateTracks(
              _tracks.copyWith(
                chapterIndex: () {
                  final i = int.tryParse(v);
                  return i == null || i < 0 ? null : i;
                },
              ),
            ),
          ),
      backend
          .observe('ab-loop-a')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(loopA: () => _optSeconds(v))),
          ),
      backend
          .observe('ab-loop-b')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(loopB: () => _optSeconds(v))),
          ),
      backend
          .observe('chapter-list/count')
          .listen((_) => unawaited(refreshChapters())),
      backend
          .observe('audio-delay')
          .listen(
            (v) => _updateTracks(_tracks.copyWith(audioDelay: _seconds(v))),
          ),
    ]);
    unawaited(_configureEngine());
  }

  /// Maximum volume in percent (task 1.6).
  static const double maxVolume = 400;

  /// Label of the limiter filter added above 100 % volume.
  static const limiterLabel = '@kyndrel-limiter';

  /// Lines of mpv log kept for error messages.
  static const logCapacity = 200;

  /// Exposed only so `PlayerVideoView` can reach the video surface.
  final PlayerBackend backend;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _controller = StreamController<PlaybackState>.broadcast();
  final _trackController = StreamController<TrackState>.broadcast();
  final _completions = StreamController<String>.broadcast();
  final _log = ListQueue<PlayerLogLine>();
  final _logLines = StreamController<PlayerLogLine>.broadcast();
  PlaybackState _state = PlaybackState.initial;
  TrackState _tracks = TrackState.empty;
  bool _disposed = false;
  bool _limiterEnabled = true;
  bool _limiterActive = false;
  RemoteTarget? _remote;
  final _headers = <String, List<String>>{};

  /// HTTP headers to send when [source] is opened (logins for WebDAV and
  /// protected streams, task 4.5). Kept in memory only.
  void setSourceHeaders(String source, List<String> headers) =>
      headers.isEmpty ? _headers.remove(source) : _headers[source] = headers;
  StreamSubscription<RemoteStatus>? _remoteSub;

  /// The cast device playing instead of the local player, if any.
  RemoteTarget? get remote => _remote;

  /// Current snapshot.
  PlaybackState get state => _state;
  TrackState get tracks => _tracks;

  /// Every state change, starting with the current state.
  ///
  /// Subscribes to live changes as soon as it is listened to, so nothing
  /// emitted between the replay and the subscription is lost.
  Stream<PlaybackState> get states => _replay(_controller, () => _state);

  /// Track list and selection changes, starting with the current value.
  Stream<TrackState> get trackStates =>
      _replay(_trackController, () => _tracks);

  /// Emits the source each time a file plays to its end. Used by the sleep
  /// timer's "end of episode" modes.
  Stream<String> get completions => _completions.stream;

  Stream<Duration> get position => states.map((s) => s.position).distinct();
  Stream<Duration> get duration => states.map((s) => s.duration).distinct();
  Stream<bool> get buffering => states.map((s) => s.isBuffering).distinct();
  Stream<PlaybackStatus> get status => states.map((s) => s.status).distinct();

  /// Most recent mpv log lines, oldest first.
  List<PlayerLogLine> get recentLog => List.unmodifiable(_log);

  /// Every mpv log line (warnings and errors) as it arrives, for the app
  /// log file (task 5.7).
  Stream<PlayerLogLine> get logLines => _logLines.stream;

  /// The last few warnings/errors, for the "can't play" message.
  String logExcerpt({int lines = 8}) {
    final relevant = _log
        .where((l) => const {'fatal', 'error', 'warn'}.contains(l.level))
        .toList();
    return relevant
        .skip(math.max(0, relevant.length - lines))
        .map((l) => '[${l.prefix}] ${l.text}')
        .join('\n');
  }

  // ---------------------------------------------------------------- opening

  /// Opens a local path or URL. Starts playing unless [play] is false.
  /// Ends casting first.
  Future<void> open(String source, {bool play = true}) async {
    // Only await when casting: the state reset below must happen
    // synchronously, before any event about the new file arrives.
    if (_remote != null) await detachRemote();
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(source, 'source', 'must not be empty');
    }
    _log.clear();
    _update(
      PlaybackState(
        source: trimmed,
        volume: _state.volume,
        isMuted: _state.isMuted,
        rate: _state.rate,
      ),
    );
    _updateTracks(TrackState.empty);
    await backend.setProperty(
      'http-header-fields',
      (_headers[trimmed] ?? const []).join(','),
    );
    await _setDemuxerCache(trimmed);
    await backend.open(trimmed, play: play);
  }

  /// mpv reads up to 150 MB ahead and keeps 50 MB behind by default. A local
  /// file is read as fast as it plays, so small buffers do (task 8.1);
  /// streams keep mpv's defaults to ride out a slow network. Options the
  /// user set in Advanced win.
  static const ({String ahead, String behind}) localDemuxerCache = (
    ahead: '32MiB',
    behind: '8MiB',
  );
  static const ({String ahead, String behind}) streamDemuxerCache = (
    ahead: '150MiB',
    behind: '50MiB',
  );

  Future<void> _setDemuxerCache(String source) async {
    final local =
        !source.contains('://') ||
        source.startsWith('file://') ||
        source.startsWith('content://');
    final size = local ? localDemuxerCache : streamDemuxerCache;
    if (!_userOptions.contains('demuxer-max-bytes')) {
      await backend.setProperty('demuxer-max-bytes', size.ahead);
    }
    if (!_userOptions.contains('demuxer-max-back-bytes')) {
      await backend.setProperty('demuxer-max-back-bytes', size.behind);
    }
  }

  /// Options set through [applyOptions] (Advanced › mpv.conf).
  final _userOptions = <String>{};

  /// Stops playback and returns to idle.
  Future<void> close() async {
    await backend.stop();
    _update(
      PlaybackState(
        volume: _state.volume,
        isMuted: _state.isMuted,
        rate: _state.rate,
      ),
    );
    _updateTracks(TrackState.empty);
  }

  // -------------------------------------------------------------- transport

  /// Hands playback to [target] (task 4.4): the local player pauses and the
  /// transport controls drive the device.
  Future<void> attachRemote(RemoteTarget target) async {
    await detachRemote();
    await backend.pause();
    _remote = target;
    _remoteSub = target.status.listen((s) {
      if (_remote != target) return;
      _update(
        _state.copyWith(
          position: s.position,
          isPlaying: s.playing,
          duration: s.duration ?? _state.duration,
        ),
      );
      if (s.finished && !_state.isCompleted) _onCompleted(true);
    });
  }

  /// Takes playback back; the local player resumes at the device's position
  /// when [resumeLocally] is set.
  Future<void> detachRemote({bool resumeLocally = false}) async {
    final r = _remote;
    if (r == null) return;
    _remote = null;
    await _remoteSub?.cancel();
    _remoteSub = null;
    final at = _state.position;
    try {
      await r.stop();
    } on Object {
      // The device may already be gone.
    }
    await backend.seek(at);
    if (resumeLocally) await backend.play();
  }

  Future<void> play() async {
    if (_state.source == null) return;
    if (_remote case final r?) {
      await r.play();
      return;
    }
    // Pressing play at the end restarts from the beginning, like most players.
    if (_state.isCompleted) await backend.seek(Duration.zero);
    await backend.play();
  }

  Future<void> pause() => _remote?.pause() ?? backend.pause();

  Future<void> playOrPause() => _state.isPlaying ? pause() : play();

  /// Seeks to [position], clamped to the file's length when it is known.
  Future<void> seek(Duration position) async {
    if (_state.source == null) return;
    if (_remote case final r?) {
      await r.seek(_clamp(position));
      return;
    }
    await backend.seek(_clamp(position));
  }

  /// Seeks relative to the current position (negative goes back).
  Future<void> seekBy(Duration offset) => seek(_state.position + offset);

  // ------------------------------------------------------------------ audio

  /// Sets the volume, 0–[maxVolume] percent. Unmutes when raised above 0.
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0, maxVolume).toDouble();
    _update(_state.copyWith(volume: v));
    if (_remote case final r?) {
      // Devices go to 100 %; boost stays local-only.
      await r.setVolume((v / 100).clamp(0, 1));
      return;
    }
    await backend.setVolume(v);
    if (v > 0 && _state.isMuted) await setMuted(muted: false);
    await _syncLimiter();
  }

  Future<void> changeVolumeBy(double delta) => setVolume(_state.volume + delta);

  Future<void> setMuted({required bool muted}) async {
    _update(_state.copyWith(isMuted: muted));
    await backend.setProperty('mute', muted ? 'yes' : 'no');
  }

  Future<void> toggleMute() => setMuted(muted: !_state.isMuted);

  /// Whether to add a limiter above 100 % to reduce clipping.
  Future<void> setLimiterEnabled({required bool enabled}) async {
    _limiterEnabled = enabled;
    await _syncLimiter();
  }

  Future<void> selectAudioTrack(int id) => backend.setProperty('aid', '$id');

  Future<void> setAudioDelay(Duration delay) =>
      backend.setProperty('audio-delay', _formatSeconds(delay));

  // ------------------------------------------------------------------ speed

  static const double minRate = 0.1;
  static const double maxRate = 4;

  Future<void> setRate(double rate) async {
    final r = rate.clamp(minRate, maxRate);
    _update(_state.copyWith(rate: r));
    await backend.setRate(r);
  }

  // -------------------------------------------------------------- subtitles

  /// Selects a subtitle track, or turns subtitles off when [id] is null.
  /// False when mpv didn't take the track (task 7.1).
  Future<bool> selectSubtitle(int? id) async {
    if (id == null) {
      await backend.setProperty('sid', 'no');
      return true;
    }
    // mpv can't show one track in both places: a track that is the
    // secondary line moves to the main one.
    if (_tracks.secondarySubtitleId == id) {
      await backend.setProperty('secondary-sid', 'no');
    }
    await backend.setProperty('sub-visibility', 'yes');
    await backend.setProperty('sid', '$id');
    // Before the file has loaded there is no track list yet; mpv applies
    // the choice when it loads.
    if (_tracks.subtitles.every((t) => t.id != id)) return true;
    final now = await backend.getProperty('sid');
    return now == null || now == '$id';
  }

  /// Second subtitle line shown at the top (dual subtitles).
  Future<void> selectSecondarySubtitle(int? id) =>
      backend.setProperty('secondary-sid', id == null ? 'no' : '$id');

  /// Adds an external subtitle file or URL and, by default, selects it.
  Future<void> addSubtitle(String path, {bool select = true, String? title}) =>
      backend.command([
        'sub-add',
        path,
        if (select) 'select' else 'auto',
        ?title,
      ]);

  Future<void> setSubtitleDelay(Duration delay) =>
      backend.setProperty('sub-delay', _formatSeconds(delay));

  /// Runs one of the user's quick commands (task 8.8): any mpv command,
  /// e.g. `cycle-values video-aspect-override 16:9 4:3 -1`.
  Future<void> runUserCommand(List<String> args) => backend.command(args);

  /// Adds an external audio file (another language, a commentary) and
  /// selects it (task 8.8).
  Future<void> addAudioTrack(String path) =>
      backend.command(['audio-add', path, 'select']);

  /// Picture adjustments, −100…100 each (task 8.8).
  static const pictureAdjustments = [
    'brightness',
    'contrast',
    'saturation',
    'gamma',
    'hue',
  ];

  Future<void> setPictureAdjustment(String name, int value) {
    assert(pictureAdjustments.contains(name), name);
    return backend.setProperty(name, '${value.clamp(-100, 100)}');
  }

  /// Sends AC-3, E-AC-3, DTS and TrueHD untouched to an AV receiver over
  /// HDMI/S/PDIF (task 8.8).
  Future<void> setAudioPassthrough({required bool enabled}) => backend
      .setProperty('audio-spdif', enabled ? 'ac3,eac3,dts,dts-hd,truehd' : '');

  Future<void> applySubtitleStyle(SubtitleStyle style) async {
    for (final e in style.toMpvOptions().entries) {
      await backend.setProperty(e.key, e.value);
    }
    // libmpv before 0.38 has no `sub-border-style`; there the background
    // box comes from the shadow, drawn in `sub-back-color`.
    final supported = await backend.getProperty('sub-border-style');
    if (supported == null || supported.isEmpty) {
      for (final e in style.toLegacyMpvOptions().entries) {
        await backend.setProperty(e.key, e.value);
      }
    }
  }

  /// Load subtitle files named like the video from the same folder
  /// (mpv `sub-auto=fuzzy`), or turn that off.
  Future<void> setAutoLoadSubtitles({required bool enabled}) =>
      backend.setProperty('sub-auto', enabled ? 'fuzzy' : 'no');

  // ------------------------------------------------------------------ video

  /// Forces a display aspect ratio such as `16:9`, or the file's own when
  /// null.
  Future<void> setAspectOverride(String? ratio) =>
      backend.setProperty('video-aspect-override', ratio ?? 'no');

  /// Rotates the picture clockwise by 0, 90, 180 or 270 degrees.
  Future<void> setRotation(int degrees) =>
      backend.setProperty('video-rotate', '${degrees % 360}');

  // ------------------------------------------------------- A-B loop, frames

  /// What [cycleLoop] did, for the on-screen message.
  static const loopSetA = 'A';
  static const loopSetB = 'B';
  static const loopCleared = 'off';

  /// First press sets A at the current position, the second sets B, the
  /// third clears the loop (task 3.9). Returns [loopSetA], [loopSetB] or
  /// [loopCleared].
  Future<String> cycleLoop() async {
    final pos = _formatSeconds(_state.position);
    if (_tracks.loopA == null) {
      await backend.setProperty('ab-loop-a', pos);
      return loopSetA;
    }
    if (_tracks.loopB == null) {
      if (_state.position <= _tracks.loopA!) {
        // B before A: start over from here.
        await backend.setProperty('ab-loop-a', pos);
        return loopSetA;
      }
      await backend.setProperty('ab-loop-b', pos);
      return loopSetB;
    }
    await clearLoop();
    return loopCleared;
  }

  Future<void> clearLoop() async {
    await backend.setProperty('ab-loop-a', 'no');
    await backend.setProperty('ab-loop-b', 'no');
  }

  /// One frame forward (pauses), or back with [forward] false.
  Future<void> frameStep({bool forward = true}) =>
      backend.command([if (forward) 'frame-step' else 'frame-back-step']);

  // --------------------------------------------------------- video quality

  /// Picture preset and optional shader files (task 4.6).
  Future<void> applyVideoPreset(
    VideoPreset preset, {
    String? shaderPath,
  }) async {
    for (final e in preset.options.entries) {
      await backend.setProperty(e.key, e.value);
    }
    await backend.setProperty(
      'glsl-shaders',
      preset.usesShader && shaderPath != null ? shaderPath : '',
    );
  }

  Future<void> setDeband({required bool enabled}) =>
      backend.setProperty('deband', enabled ? 'yes' : 'no');

  /// HDR to SDR tone mapping curve; peak detection follows it.
  Future<void> setToneMapping(String curve) async {
    await backend.setProperty('tone-mapping', curve);
    await backend.setProperty('hdr-compute-peak', 'auto');
  }

  /// mpv `hwdec`: `auto-safe`, `no`, or a specific API.
  Future<void> setHardwareDecoding(String mode) =>
      backend.setProperty('hwdec', mode);

  String? _videoTrackWhileHidden;

  /// Stops decoding the picture while nobody can see it, such as a phone
  /// playing in the background (task 6.7), and brings it back. mpv `vid`.
  Future<void> setVideoDecoding({required bool enabled}) async {
    if (!enabled) {
      if (_videoTrackWhileHidden != null) return;
      final vid = await backend.getProperty('vid');
      if (vid == null || vid == 'no' || vid.isEmpty) return;
      _videoTrackWhileHidden = vid;
      await backend.setProperty('vid', 'no');
    } else {
      final vid = _videoTrackWhileHidden;
      if (vid == null) return;
      _videoTrackWhileHidden = null;
      await backend.setProperty('vid', vid);
    }
  }

  // ------------------------------------------------------ music (7.6)

  /// The level meter's mpv filter label.
  static const _meter = '@kviz';
  bool _meterOn = false;

  /// Measures the loudness for the music view's waves (an `astats` audio
  /// filter); off when nothing shows it.
  Future<void> setLevelMeter({required bool enabled}) async {
    if (enabled == _meterOn) return;
    _meterOn = enabled;
    await backend.command(
      enabled
          ? ['af', 'add', '$_meter:lavfi=[astats=metadata=1:reset=1]']
          : ['af', 'remove', _meter],
    );
  }

  /// The loudness about every [interval] while listened to and the meter
  /// is on. The whole `af-metadata` object is read: asking mpv for one of
  /// its keys crashes libmpv.
  Stream<AudioLevel> levels({
    Duration interval = const Duration(milliseconds: 60),
  }) => Stream<void>.periodic(interval).asyncMap((_) async {
    if (!_meterOn || !_state.isPlaying) return AudioLevel.silent;
    return AudioLevel.parse(await backend.getProperty('af-metadata/kviz'));
  });

  /// The current file's title, artist and album tags.
  Future<({String? title, String? artist, String? album})> readTags() async {
    Future<String?> tag(String key) async =>
        _nonEmpty(await backend.getProperty('metadata/by-key/$key'));
    return (
      title: await tag('title'),
      artist: await tag('artist'),
      album: await tag('album'),
    );
  }

  // --------------------------------------------------------- audio effects

  static const eqLabel = '@kyndrel-eq';
  static const normLabel = '@kyndrel-norm';

  /// 10-band equalizer gains in dB (task 4.7); all zeros removes it.
  Future<void> setEqualizer(List<double> gains) =>
      _setAudioFilter(eqLabel, Equalizer.filter(gains));

  Future<void> setNormalization(Normalization mode) =>
      _setAudioFilter(normLabel, mode.filter);

  final _audioFilters = <String, String>{};

  Future<void> _setAudioFilter(String label, String? graph) async {
    if (_audioFilters[label] == graph) return;
    if (_audioFilters.containsKey(label)) {
      await backend.command(['af', 'remove', label]);
      _audioFilters.remove(label);
    }
    if (graph != null) {
      await backend.command(['af', 'add', '$label:lavfi=[$graph]']);
      _audioFilters[label] = graph;
    }
  }

  /// Applies `mpv.conf`-style options (advanced settings, task 5.1).
  /// Returns the options mpv rejected.
  Future<List<String>> applyOptions(Map<String, String> options) async {
    _userOptions
      ..clear()
      ..addAll(options.keys);
    final rejected = <String>[];
    for (final e in options.entries) {
      try {
        await backend.setProperty(e.key, e.value);
      } on Object {
        rejected.add(e.key);
      }
    }
    return rejected;
  }

  // ---------------------------------------------------------------- scripts

  /// Loads an mpv Lua or JavaScript user script (task 4.9).
  Future<void> loadScript(String path) =>
      backend.command(['load-script', path]);

  /// Sends `script-message <args>` to every loaded script.
  Future<void> scriptMessage(List<String> args) =>
      backend.command(['script-message', ...args]);

  /// Text scripts ask Kyndrel to show: a script sets the mpv property
  /// `user-data/kyndrel/osd` (e.g. `mp.set_property("user-data/kyndrel/osd",
  /// "Hi")`).
  Stream<String> get scriptOsd => backend
      .observe('user-data/kyndrel/osd')
      .map(_decodeUserData)
      .where((t) => t.isNotEmpty);

  /// mpv returns `user-data` nodes JSON-formatted (`"text"`).
  static String _decodeUserData(String raw) {
    if (!raw.startsWith('"')) return raw;
    try {
      return jsonDecode(raw) as String;
    } on FormatException {
      return raw;
    }
  }

  // ------------------------------------------------------------ screenshots

  /// Saves the current frame to [path] (PNG or JPEG by extension).
  /// [withSubtitles] includes the subtitles as shown.
  Future<void> screenshotTo(String path, {bool withSubtitles = false}) =>
      backend.command([
        'screenshot-to-file',
        path,
        if (withSubtitles) 'subtitles' else 'video',
      ]);

  // ------------------------------------------------------------------- info

  /// The hardware decoder mpv is using (e.g. `d3d11va`), or null if decoding
  /// in software or unknown.
  Future<String?> hardwareDecoder() async {
    final value = await backend.getProperty('hwdec-current');
    if (value == null || value.isEmpty || value == 'no') return null;
    return value;
  }

  /// mpv properties shown in the diagnostics overlay (`--diagnostics`).
  static const diagnosticProperties = [
    'hwdec-current',
    'video-codec',
    'width',
    'height',
    'container-fps',
    'estimated-vf-fps',
    'frame-drop-count',
    // The statistics overlay (task 8.8).
    'video-bitrate',
    'audio-bitrate',
    'audio-codec',
    'demuxer-cache-duration',
  ];

  /// Current values of [diagnosticProperties]; unavailable ones are omitted.
  Future<Map<String, String>> diagnostics() =>
      _readProperties(diagnosticProperties);

  /// mpv properties shown in the media info dialog.
  static const mediaInfoProperties = [
    'filename',
    'path',
    'file-format',
    'file-size',
    'duration',
    'video-codec',
    'video-params/w',
    'video-params/h',
    'container-fps',
    'video-params/pixelformat',
    'video-params/colormatrix',
    'video-params/primaries',
    'video-params/gamma',
    'video-bitrate',
    'audio-codec',
    'audio-params/channel-count',
    'audio-params/hr-channels',
    'chapters',
    'audio-params/samplerate',
    'audio-bitrate',
    'hwdec-current',
  ];

  Future<Map<String, String>> mediaInfo() =>
      _readProperties(mediaInfoProperties);

  /// Re-reads mpv's `chapter-list` (task 3.6).
  Future<void> refreshChapters() async {
    final count =
        int.tryParse(await backend.getProperty('chapter-list/count') ?? '') ??
        0;
    final chapters = <Chapter>[];
    for (var i = 0; i < count; i++) {
      final time = double.tryParse(
        await backend.getProperty('chapter-list/$i/time') ?? '',
      );
      if (time == null) continue;
      chapters.add(
        Chapter(
          start: Duration(microseconds: (time * 1e6).round()),
          title: _nonEmpty(await backend.getProperty('chapter-list/$i/title')),
        ),
      );
    }
    _updateTracks(_tracks.copyWith(chapters: chapters));
  }

  /// Jumps to the next (or, with [delta] -1, previous) chapter.
  Future<void> chapterBy(int delta) async {
    if (_tracks.chapters.isEmpty) return;
    await backend.command(['add', 'chapter', '$delta']);
  }

  /// Re-reads mpv's `track-list`.
  Future<void> refreshTracks() async {
    final count = int.tryParse(
      await backend.getProperty('track-list/count') ?? '',
    );
    if (count == null) return;
    final video = <MediaTrack>[];
    final audio = <MediaTrack>[];
    final subs = <MediaTrack>[];
    for (var i = 0; i < count; i++) {
      Future<String?> p(String name) =>
          backend.getProperty('track-list/$i/$name');
      final id = int.tryParse(await p('id') ?? '');
      final type = switch (await p('type')) {
        'video' => MediaTrackType.video,
        'audio' => MediaTrackType.audio,
        'sub' => MediaTrackType.subtitle,
        _ => null,
      };
      if (id == null || type == null) continue;
      final track = MediaTrack(
        id: id,
        type: type,
        title: _nonEmpty(await p('title')),
        language: _nonEmpty(await p('lang')),
        codec: _nonEmpty(await p('codec')),
        isExternal: await p('external') == 'yes',
        externalFilename: _nonEmpty(await p('external-filename')),
        isDefault: await p('default') == 'yes',
        isForced: await p('forced') == 'yes',
        channels: int.tryParse(await p('demux-channel-count') ?? ''),
        isCoverArt: await p('albumart') == 'yes',
      );
      (switch (type) {
        MediaTrackType.video => video,
        MediaTrackType.audio => audio,
        MediaTrackType.subtitle => subs,
      }).add(track);
    }
    _updateTracks(
      _tracks.copyWith(video: video, audio: audio, subtitles: subs),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _remoteSub?.cancel();
    await _controller.close();
    await _trackController.close();
    await _completions.close();
    await _logLines.close();
    _audioRetry?.cancel();
    await _audioProblems.close();
    await backend.dispose();
  }

  // ---------------------------------------------------------------- private

  Future<void> _configureEngine() async {
    await backend.setProperty('volume-max', maxVolume.toStringAsFixed(0));
    await backend.setProperty('audio-pitch-correction', 'yes');
    // FFmpeg retries a dropped HTTP connection with growing delays (0, 1,
    // 3, 7, 15 s ...). Its default cap means ~2 minutes of spinner before
    // an error; stop after the 15 s retry instead (task 5.5).
    // (The option's default value is empty, so setting it replaces nothing;
    // Settings › Advanced › mpv options can still override it.)
    await backend.setProperty(
      'stream-lavf-o',
      'reconnect_delay_max=$reconnectDelayMaxSeconds',
    );
  }

  /// Longest wait between reconnect attempts on a dropped stream.
  static const reconnectDelayMaxSeconds = 15;

  Future<void> _syncLimiter() async {
    final want = _limiterEnabled && _state.volume > 100;
    if (want == _limiterActive) return;
    _limiterActive = want;
    await backend.command(
      want
          ? ['af', 'add', '$limiterLabel:lavfi=[alimiter=limit=0.9]']
          : ['af', 'remove', limiterLabel],
    );
  }

  Future<Map<String, String>> _readProperties(List<String> names) async {
    final values = <String, String>{};
    for (final name in names) {
      final v = await backend.getProperty(name);
      if (v != null && v.isNotEmpty) values[name] = v;
    }
    return values;
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final d = _state.duration;
    if (d > Duration.zero && position > d) return d;
    return position;
  }

  /// How far before the known duration an end of file counts as "cut
  /// short" rather than "finished": the larger of 5 s and 3 %.
  static Duration earlyEndMargin(Duration duration) {
    final pct = duration * 0.03;
    return pct > const Duration(seconds: 5) ? pct : const Duration(seconds: 5);
  }

  void _onCompleted(bool completed) {
    // mpv reports a dropped stream or a truncated file as a normal end of
    // file once it gives up. Don't treat a cut-off film as watched (resume
    // point, history, next in queue): report it as an error (task 5.5).
    final d = _state.duration;
    final at = _state.position;
    if (completed &&
        _remote == null &&
        d > Duration.zero &&
        at < d - earlyEndMargin(d)) {
      final source = _state.source ?? '';
      final network =
          RegExp('^[a-z][a-z0-9+.-]*://').hasMatch(source) &&
          !source.startsWith('file://');
      _update(
        _state.copyWith(
          endedEarly: true,
          isPlaying: false,
          errorMessage: network
              ? 'The connection was lost at ${formatDuration(at)}.'
              : 'The file ends early, at ${formatDuration(at)} of '
                    '${formatDuration(d)}. It may be incomplete or damaged.',
        ),
      );
      return;
    }
    final wasCompleted = _state.isCompleted;
    _update(_state.copyWith(isCompleted: completed));
    final source = _state.source;
    if (completed && !wasCompleted && source != null && !_disposed) {
      _completions.add(source);
    }
  }

  /// mpv errors that never stop playback (no sound card, a missing audio
  /// driver). They stay in the log but don't count as "can't play".
  static final _nonFatal = RegExp(
    'audio (device|driver|output)|no sound|ao[/ ]',
    caseSensitive: false,
  );

  void _onError(String message) {
    if (message.trim().isEmpty) return;
    if (_nonFatal.hasMatch(message)) {
      _onAudioProblem(message);
      return;
    }
    _update(_state.copyWith(errorMessage: message));
  }

  // ---------------------------------------------------------- sound output

  final _audioProblems = StreamController<String>.broadcast();

  /// mpv couldn't open the sound device: the film plays, silently. Each
  /// file gets one automatic retry ([audioRetryDelay] later, `ao-reload`);
  /// every problem is reported here so the app can say so instead of
  /// staying silent.
  Stream<String> get audioProblems => _audioProblems.stream;

  static const audioRetryDelay = Duration(milliseconds: 500);
  String? _audioRetried;
  Timer? _audioRetry;

  void _onAudioProblem(String message) {
    if (_disposed) return;
    if (!_audioProblems.isClosed) _audioProblems.add(message.trim());
    final source = _state.source;
    if (source == null || _audioRetried == source) return;
    _audioRetried = source;
    _audioRetry?.cancel();
    _audioRetry = Timer(audioRetryDelay, () {
      if (_disposed) return;
      unawaited(
        backend.command(['ao-reload']).catchError((Object _) {
          // Nothing playing any more.
        }),
      );
    });
  }

  /// The sound devices mpv can play to; the first is `auto`, the system's
  /// default.
  Future<List<SoundDevice>> audioDevices() async =>
      SoundDevice.parseList(await backend.getProperty('audio-device-list'));

  /// Plays sound on [name] (from [audioDevices]); `auto` follows the
  /// system's default device.
  Future<void> setAudioDevice(String name) async {
    _audioRetried = null;
    await backend.setProperty('audio-device', name.isEmpty ? 'auto' : name);
  }

  void _onLog(PlayerLogLine line) {
    if (!_logLines.isClosed) _logLines.add(line);
    _log.addLast(line);
    while (_log.length > logCapacity) {
      _log.removeFirst();
    }
  }

  void _update(PlaybackState next) {
    if (_disposed || next == _state) return;
    _state = next;
    _controller.add(next);
  }

  void _updateTracks(TrackState next) {
    if (_disposed || next == _tracks) return;
    _tracks = next;
    _trackController.add(next);
  }

  static Stream<T> _replay<T>(StreamController<T> source, T Function() now) =>
      Stream.multi((listener) {
        listener.add(now());
        final sub = source.stream.listen(
          listener.addSync,
          onDone: listener.closeSync,
        );
        listener.onCancel = sub.cancel;
      });

  static int? _id(String value) => int.tryParse(value);

  static Duration? _optSeconds(String value) {
    final s = double.tryParse(value);
    return s == null ? null : Duration(microseconds: (s * 1e6).round());
  }

  static Duration _seconds(String value) {
    final s = double.tryParse(value) ?? 0;
    return Duration(microseconds: (s * 1e6).round());
  }

  static String _formatSeconds(Duration d) =>
      (d.inMicroseconds / 1e6).toStringAsFixed(3);

  static String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
}

/// A sound device from mpv's `audio-device-list`.
@immutable
class SoundDevice {
  const new(this.name, this.description);

  /// What `audio-device` takes, like `wasapi/{...}` or `pulse/alsa_output...`.
  final String name;
  final String description;

  static const automatic = SoundDevice('auto', 'Automatic');

  /// Parses mpv's JSON list; [automatic] always comes first.
  static List<SoundDevice> parseList(String? json) {
    final out = [automatic];
    if (json == null || json.isEmpty) return out;
    try {
      final list = jsonDecode(json);
      if (list is! List) return out;
      for (final e in list) {
        if (e is! Map) continue;
        final name = e['name'];
        if (name is! String || name.isEmpty || name == 'auto') continue;
        final d = e['description'];
        out.add(SoundDevice(name, d is String && d.isNotEmpty ? d : name));
      }
    } on FormatException {
      // Not JSON: automatic only.
    }
    return out;
  }

  @override
  bool operator ==(Object other) => other is SoundDevice && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
