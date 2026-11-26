import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';

import '../../support/fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late PlayerService service;

  setUp(() {
    backend = FakePlayerBackend();
    service = PlayerService(backend);
  });

  tearDown(() => service.dispose());

  test('starts idle', () {
    expect(service.state.status, PlaybackStatus.idle);
    expect(service.state.source, isNull);
  });

  test(
    'open trims the source, resets state and asks the backend to play',
    () async {
      backend.emitPosition(const Duration(seconds: 5));
      await service.open('  /videos/a.mkv ');

      expect(backend.calls, ['open(/videos/a.mkv, play: true)']);
      expect(service.state.source, '/videos/a.mkv');
      expect(service.state.position, Duration.zero);
      expect(service.state.status, PlaybackStatus.loading);
    },
  );

  test('open can leave the file paused', () async {
    await service.open('a.mp4', play: false);
    expect(backend.calls, ['open(a.mp4, play: false)']);
  });

  test('small demuxer buffers for local files, mpv defaults for streams '
      '(8.1)', () async {
    String ahead() => backend.properties['demuxer-max-bytes']!;
    String behind() => backend.properties['demuxer-max-back-bytes']!;
    await service.open('/v/film.mkv');
    expect((ahead(), behind()), ('32MiB', '8MiB'));
    await service.open('content://media/external/video/media/7');
    expect(ahead(), '32MiB');
    await service.open('https://x.example/live.m3u8');
    expect((ahead(), behind()), ('150MiB', '50MiB'));

    // The user's own mpv.conf value wins.
    await service.applyOptions({'demuxer-max-bytes': '64MiB'});
    await service.open('/v/film.mkv');
    expect((ahead(), behind()), ('64MiB', '8MiB'));
  });

  test('open rejects an empty source', () {
    expect(() => service.open('   '), throwsArgumentError);
    expect(backend.calls, isEmpty);
  });

  test('loading becomes paused once a duration arrives', () async {
    await service.open('a.mp4', play: false);
    backend.emitDuration(const Duration(minutes: 2));
    expect(service.state.status, PlaybackStatus.paused);
    expect(service.state.duration, const Duration(minutes: 2));
  });

  test('playing true moves to playing, false to paused', () async {
    await service.open('a.mp4');
    backend.emitPlaying(value: true);
    expect(
      service.state.status,
      PlaybackStatus.loading,
      reason: 'media_kit says playing before the file is read',
    );
    backend.emitDuration(const Duration(minutes: 1));
    expect(service.state.status, PlaybackStatus.playing);
    backend.emitPlaying(value: false);
    expect(service.state.status, PlaybackStatus.paused);
  });

  test(
    'a live stream with no duration still loads once a frame size arrives',
    () async {
      await service.open('https://example.com/live.m3u8', play: false);
      backend.emitSize(1920, 1080);
      expect(service.state.status, PlaybackStatus.paused);
      expect(service.state.videoWidth, 1920);
      expect(service.state.videoHeight, 1080);
    },
  );

  test('completed status', () async {
    await service.open('a.mp4');
    backend
      ..emitDuration(const Duration(seconds: 10))
      ..emitPosition(const Duration(seconds: 10))
      ..emitCompleted(value: true);
    expect(service.state.status, PlaybackStatus.completed);
  });

  test('an error before the file loads is fatal', () async {
    await service.open('a.mp4');
    backend.emitError('Failed to open a.mp4.');
    expect(service.state.status, PlaybackStatus.error);
    expect(service.state.errorMessage, 'Failed to open a.mp4.');
  });

  test('an error after the file loads is only a warning', () async {
    await service.open('a.mp4');
    backend
      ..emitDuration(const Duration(seconds: 10))
      ..emitPlaying(value: true)
      ..emitError('Error decoding a frame.');
    expect(service.state.status, PlaybackStatus.playing);
    expect(service.state.errorMessage, 'Error decoding a frame.');
  });

  test('audio device errors never count as fatal', () async {
    await service.open('a.mp4');
    backend.emitError('Could not open/initialize audio device -> no sound.');
    expect(service.state.status, PlaybackStatus.loading);
    expect(service.state.errorMessage, isNull);
  });

  test('a broken file opened after a playing one shows the error', () async {
    await service.open('good.mp4');
    backend
      ..emitDuration(const Duration(minutes: 1))
      ..emitPlaying(value: true);
    await service.open('broken.mkv');
    backend
      ..emitPlaying(value: true)
      ..emitError('Failed to recognize file format.');
    expect(service.state.status, PlaybackStatus.error);
  });

  test('libmpv without sub-border-style gets the shadow fallback', () async {
    await service.applySubtitleStyle(const SubtitleStyle(backgroundBox: true));
    // The fake stores any property, so it "supports" it.
    expect(backend.properties['sub-shadow-offset'], isNull);
    backend.properties.remove('sub-border-style');
    final legacy = _LegacyBackend();
    final s2 = PlayerService(legacy);
    await s2.applySubtitleStyle(const SubtitleStyle(backgroundBox: true));
    expect(legacy.properties['sub-shadow-offset'], '4');
    await s2.dispose();
  });

  test('blank error messages are ignored', () async {
    await service.open('a.mp4');
    backend.emitError('  ');
    expect(service.state.errorMessage, isNull);
  });

  test('opening a new source clears a previous error', () async {
    await service.open('bad.mp4');
    backend.emitError('boom');
    await service.open('good.mp4');
    expect(service.state.errorMessage, isNull);
    expect(service.state.status, PlaybackStatus.loading);
  });

  test('buffering and buffered amount are tracked', () async {
    await service.open('a.mp4');
    backend
      ..emitBuffering(value: true)
      ..emitBuffer(const Duration(seconds: 30));
    expect(service.state.isBuffering, isTrue);
    expect(service.state.buffered, const Duration(seconds: 30));
  });

  group('commands', () {
    test('do nothing before a source is opened', () async {
      await service.play();
      await service.seek(const Duration(seconds: 3));
      expect(backend.calls, isEmpty);
    });

    test('playOrPause toggles based on state', () async {
      await service.open('a.mp4');
      backend.calls.clear();
      await service.playOrPause();
      backend.emitPlaying(value: true);
      await service.playOrPause();
      expect(backend.calls, ['play', 'pause']);
    });

    test('play after completion restarts from the beginning', () async {
      await service.open('a.mp4');
      backend.emitCompleted(value: true);
      backend.calls.clear();
      await service.play();
      expect(backend.calls, ['seek(0)', 'play']);
    });

    test('seek clamps to 0 and to the known duration', () async {
      await service.open('a.mp4');
      backend.emitDuration(const Duration(seconds: 60));
      backend.calls.clear();
      await service.seek(const Duration(seconds: -5));
      await service.seek(const Duration(seconds: 90));
      await service.seek(const Duration(seconds: 30));
      expect(backend.calls, ['seek(0)', 'seek(60000)', 'seek(30000)']);
    });

    test('seek is not clamped above when the duration is unknown', () async {
      await service.open('live');
      backend.calls.clear();
      await service.seek(const Duration(hours: 5));
      expect(backend.calls, ['seek(18000000)']);
    });

    test('seekBy is relative to the current position', () async {
      await service.open('a.mp4');
      backend
        ..emitDuration(const Duration(minutes: 1))
        ..emitPosition(const Duration(seconds: 20));
      backend.calls.clear();
      await service.seekBy(const Duration(seconds: 10));
      await service.seekBy(const Duration(seconds: -30));
      expect(backend.calls, ['seek(30000)', 'seek(0)']);
    });
  });

  group('streams', () {
    test('no change is lost between the replay and live updates', () async {
      await service.open('a.mp4');
      backend.emitDuration(const Duration(minutes: 1));
      final received = <PlaybackStatus>[];
      final sub = service.status.listen(received.add);
      // Emitted synchronously, before any microtask has run.
      backend.emitPlaying(value: true);
      await pumpEventQueue();
      await sub.cancel();
      expect(received, [PlaybackStatus.paused, PlaybackStatus.playing]);
    });

    test('states replays the current state first, then changes', () async {
      await service.open('a.mp4');
      backend.emitDuration(const Duration(minutes: 1));
      final received = <PlaybackStatus>[];
      final sub = service.status.listen(received.add);
      await pumpEventQueue();
      backend.emitPlaying(value: true);
      await pumpEventQueue();
      await sub.cancel();
      expect(received, [PlaybackStatus.paused, PlaybackStatus.playing]);
    });

    test('position stream skips duplicates', () async {
      await service.open('a.mp4');
      final received = <Duration>[];
      final sub = service.position.listen(received.add);
      await pumpEventQueue();
      backend
        ..emitPosition(const Duration(seconds: 1))
        ..emitBuffering(value: true) // unrelated change
        ..emitPosition(const Duration(seconds: 2));
      await pumpEventQueue();
      await sub.cancel();
      expect(received, [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });
  });

  test('hardwareDecoder maps "no" and missing values to null', () async {
    expect(await service.hardwareDecoder(), isNull);
    backend.properties['hwdec-current'] = 'no';
    expect(await service.hardwareDecoder(), isNull);
    backend.properties['hwdec-current'] = 'd3d11va';
    expect(await service.hardwareDecoder(), 'd3d11va');
  });

  test('diagnostics returns only available properties', () async {
    backend.properties
      ..['hwdec-current'] = 'nvdec'
      ..['width'] = '3840';
    expect(await service.diagnostics(), {
      'hwdec-current': 'nvdec',
      'width': '3840',
    });
  });

  test('dispose disposes the backend once and ignores later events', () async {
    await service.dispose();
    await service.dispose();
    expect(backend.calls.where((c) => c == 'dispose'), hasLength(1));
    expect(backend.disposed, isTrue);
  });

  test('engine is configured for 400 % volume and pitch correction', () async {
    await pumpEventQueue();
    expect(backend.properties['volume-max'], '400');
    expect(backend.properties['audio-pitch-correction'], 'yes');
  });

  group('volume', () {
    test('clamps to 0–400', () async {
      await service.setVolume(520);
      expect(service.state.volume, 400);
      await service.setVolume(-3);
      expect(service.state.volume, 0);
      expect(backend.calls, ['volume(400.0)', 'volume(0.0)']);
    });

    test('adds the limiter above 100 % and removes it below', () async {
      await service.setVolume(150);
      await service.setVolume(180);
      await service.setVolume(90);
      expect(backend.commands, [
        ['af', 'add', '@kyndrel-limiter:lavfi=[alimiter=limit=0.9]'],
        ['af', 'remove', '@kyndrel-limiter'],
      ]);
    });

    test('limiter can be turned off', () async {
      await service.setVolume(200);
      await service.setLimiterEnabled(enabled: false);
      expect(backend.commands.last, ['af', 'remove', '@kyndrel-limiter']);
      await service.setVolume(250);
      expect(backend.commands, hasLength(2));
    });

    test('mute toggles mpv mute and raising volume unmutes', () async {
      await service.toggleMute();
      expect(service.state.isMuted, isTrue);
      expect(backend.properties['mute'], 'yes');
      await service.changeVolumeBy(5);
      expect(service.state.isMuted, isFalse);
      expect(backend.properties['mute'], 'no');
    });
  });

  test('rate is clamped to 0.1–4', () async {
    await service.setRate(10);
    await service.setRate(0);
    await service.setRate(1.25);
    expect(backend.calls, ['rate(4.0)', 'rate(0.1)', 'rate(1.25)']);
    expect(service.state.rate, 1.25);
  });

  test('volume, mute and rate survive opening another file', () async {
    await service.setVolume(250);
    await service.setRate(1.5);
    await service.open('b.mkv');
    expect(service.state.volume, 250);
    expect(service.state.rate, 1.5);
  });

  test('close stops and returns to idle', () async {
    await service.open('a.mp4');
    await service.close();
    expect(backend.calls.last, 'stop');
    expect(service.state.status, PlaybackStatus.idle);
  });

  group('tracks', () {
    test('parses mpv track-list', () async {
      backend.emitTracks([
        {'id': '1', 'type': 'video', 'codec': 'h264'},
        {
          'id': '1',
          'type': 'audio',
          'lang': 'eng',
          'title': 'Stereo',
          'default': 'yes',
          'demux-channel-count': '2',
        },
        {'id': '2', 'type': 'audio', 'lang': 'ara'},
        {'id': '1', 'type': 'sub', 'lang': 'eng', 'codec': 'subrip'},
        {
          'id': '2',
          'type': 'sub',
          'codec': 'hdmv_pgs_subtitle',
          'forced': 'yes',
        },
        {
          'id': '3',
          'type': 'sub',
          'external': 'yes',
          'external-filename': '/v/a.ar.srt',
          'lang': 'ar',
        },
      ]);
      await pumpEventQueue();
      final t = service.tracks;
      expect(t.video, hasLength(1));
      expect(t.audio.map((a) => a.language), ['eng', 'ara']);
      expect(t.audio.first.channels, 2);
      expect(t.audio.first.isDefault, isTrue);
      expect(t.subtitles, hasLength(3));
      expect(t.subtitles[1].isImageSubtitle, isTrue);
      expect(t.subtitles[1].isForced, isTrue);
      expect(t.subtitles[2].isExternal, isTrue);
      expect(t.subtitles[2].externalFilename, '/v/a.ar.srt');
    });

    test('selection and delays follow mpv properties', () async {
      backend
        ..emitProperty('sid', '2')
        ..emitProperty('aid', '1')
        ..emitProperty('secondary-sid', 'no')
        ..emitProperty('sub-delay', '-0.500000')
        ..emitProperty('audio-delay', '0.250000');
      expect(service.tracks.subtitleId, 2);
      expect(service.tracks.audioId, 1);
      expect(service.tracks.secondarySubtitleId, isNull);
      expect(service.tracks.subtitleDelay, const Duration(milliseconds: -500));
      expect(service.tracks.audioDelay, const Duration(milliseconds: 250));
      backend.emitProperty('sid', 'no');
      expect(service.tracks.subtitleId, isNull);
    });

    test('commands map to mpv', () async {
      await service.selectSubtitle(3);
      expect(backend.properties['sid'], '3');
      await service.selectSubtitle(null);
      expect(backend.properties['sid'], 'no');
      await service.selectSecondarySubtitle(1);
      expect(backend.properties['secondary-sid'], '1');
      await service.selectAudioTrack(2);
      expect(backend.properties['aid'], '2');
      await service.setSubtitleDelay(const Duration(milliseconds: 1500));
      expect(backend.properties['sub-delay'], '1.500');
      await service.setAudioDelay(const Duration(milliseconds: -100));
      expect(backend.properties['audio-delay'], '-0.100');
      await service.addSubtitle('/v/x.srt');
      await service.addSubtitle('/v/y.srt', select: false, title: 'Y');
      expect(backend.commands, [
        ['sub-add', '/v/x.srt', 'select'],
        ['sub-add', '/v/y.srt', 'auto', 'Y'],
      ]);
      await service.setAutoLoadSubtitles(enabled: true);
      expect(backend.properties['sub-auto'], 'fuzzy');
    });

    test('subtitle style is applied as sub-* options', () async {
      await service.applySubtitleStyle(
        const SubtitleStyle(size: 50, position: 90, backgroundBox: true),
      );
      expect(backend.properties['sub-font-size'], '50');
      expect(backend.properties['sub-pos'], '90');
      expect(backend.properties['sub-border-style'], 'opaque-box');
    });

    test('opening a file clears the old track list', () async {
      backend.emitTracks([
        {'id': '1', 'type': 'sub'},
      ]);
      await pumpEventQueue();
      await service.open('b.mkv');
      expect(service.tracks.subtitles, isEmpty);
    });
  });

  group('an end of file well before the duration (task 5.5)', () {
    test('a cut-off network stream is an error, not a completion', () async {
      final ends = <String>[];
      service.completions.listen(ends.add);
      await service.open('https://example.com/film.mkv');
      backend
        ..emitDuration(const Duration(minutes: 90))
        ..emitPosition(const Duration(minutes: 12))
        ..emitCompleted(value: true);
      await pumpEventQueue();
      expect(service.state.status, PlaybackStatus.error);
      expect(service.state.errorMessage, contains('connection was lost'));
      expect(service.state.errorMessage, contains('12:00'));
      expect(ends, isEmpty);
    });

    test('a truncated local file says it ends early', () async {
      await service.open('/v/film.mkv');
      backend
        ..emitDuration(const Duration(minutes: 90))
        ..emitPosition(const Duration(minutes: 40))
        ..emitCompleted(value: true);
      await pumpEventQueue();
      expect(service.state.errorMessage, contains('ends early'));
    });

    test('ending within the margin is a normal completion', () async {
      await service.open('/v/film.mkv');
      backend
        ..emitDuration(const Duration(minutes: 90))
        // 3 % of 90 min is 2 min 42 s: credits cut short still count.
        ..emitPosition(const Duration(minutes: 88))
        ..emitCompleted(value: true);
      await pumpEventQueue();
      expect(service.state.status, PlaybackStatus.completed);
      expect(
        PlayerService.earlyEndMargin(const Duration(seconds: 30)),
        const Duration(seconds: 5),
      );
    });
  });

  test('stream reconnects give up after the 15 s retry', () async {
    await pumpEventQueue();
    expect(backend.properties['stream-lavf-o'], 'reconnect_delay_max=15');
  });

  test('completions fire once per file end', () async {
    final ends = <String>[];
    service.completions.listen(ends.add);
    await service.open('ep1.mkv');
    backend
      ..emitCompleted(value: true)
      ..emitCompleted(value: true);
    await pumpEventQueue();
    expect(ends, ['ep1.mkv']);
  });

  test('log excerpt keeps recent warnings and errors only', () async {
    await service.open('a.mp4');
    backend
      ..emitLog('info', 'cplayer', 'noise')
      ..emitLog('warn', 'ffmpeg', 'Invalid data found')
      ..emitLog('error', 'cplayer', 'Failed to recognize file format.');
    expect(
      service.logExcerpt(),
      '[ffmpeg] Invalid data found\n'
      '[cplayer] Failed to recognize file format.',
    );
    expect(service.recentLog, hasLength(3));
  });

  test('aspect override and rotation', () async {
    await service.setAspectOverride('16:9');
    expect(backend.properties['video-aspect-override'], '16:9');
    await service.setAspectOverride(null);
    expect(backend.properties['video-aspect-override'], 'no');
    await service.setRotation(450);
    expect(backend.properties['video-rotate'], '90');
  });

  test('limiter label constant', () {
    expect(PlayerService.limiterLabel, startsWith('@'));
  });

  group('chapters', () {
    void chapters() {
      backend.properties
        ..['chapter-list/0/time'] = '0.000000'
        ..['chapter-list/0/title'] = 'Intro'
        ..['chapter-list/1/time'] = '90.500000'
        ..['chapter-list/1/title'] = 'Part 1'
        ..['chapter-list/2/time'] = '600.000000';
      backend.emitProperty('chapter-list/count', '3');
    }

    test('are read from chapter-list', () async {
      chapters();
      await pumpEventQueue();
      final c = service.tracks.chapters;
      expect(c.map((e) => e.title), ['Intro', 'Part 1', null]);
      expect(c[1].start, const Duration(milliseconds: 90500));
      expect(
        service.tracks.chapterAt(const Duration(minutes: 5))?.title,
        'Part 1',
      );
    });

    test(
      'current chapter follows mpv; next/previous use add chapter',
      () async {
        chapters();
        await pumpEventQueue();
        backend.emitProperty('chapter', '1');
        expect(service.tracks.chapterIndex, 1);
        await service.chapterBy(1);
        await service.chapterBy(-1);
        expect(backend.commands, [
          ['add', 'chapter', '1'],
          ['add', 'chapter', '-1'],
        ]);
      },
    );

    test('no chapters: next/previous do nothing', () async {
      await service.chapterBy(1);
      expect(backend.commands, isEmpty);
    });
  });

  group('A-B loop and frame step', () {
    test('L cycles A, B, clear', () async {
      await service.open('a.mp4');
      backend
        ..emitDuration(const Duration(minutes: 10))
        ..emitPosition(const Duration(seconds: 30));
      expect(await service.cycleLoop(), PlayerService.loopSetA);
      expect(service.tracks.loopA, const Duration(seconds: 30));
      backend.emitPosition(const Duration(seconds: 45));
      expect(await service.cycleLoop(), PlayerService.loopSetB);
      expect(service.tracks.loopB, const Duration(seconds: 45));
      expect(await service.cycleLoop(), PlayerService.loopCleared);
      expect(backend.properties['ab-loop-a'], 'no');
      expect(service.tracks.loopA, isNull);
      expect(service.tracks.loopB, isNull);
    });

    test('B before A restarts from the new point', () async {
      await service.open('a.mp4');
      backend.emitPosition(const Duration(seconds: 30));
      await service.cycleLoop();
      backend.emitPosition(const Duration(seconds: 10));
      expect(await service.cycleLoop(), PlayerService.loopSetA);
      expect(service.tracks.loopA, const Duration(seconds: 10));
    });

    test('frame step commands', () async {
      await service.frameStep();
      await service.frameStep(forward: false);
      expect(backend.commands, [
        ['frame-step'],
        ['frame-back-step'],
      ]);
    });
  });
}

/// A backend whose mpv doesn't know `sub-border-style` (libmpv < 0.38).
class _LegacyBackend extends FakePlayerBackend {
  @override
  Future<void> setProperty(String name, String value) async {
    if (name == 'sub-border-style') return;
    await super.setProperty(name, value);
  }
}
