import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_service.dart';

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
      ..emitError('Could not open/initialize audio device -> no sound.');
    expect(service.state.status, PlaybackStatus.playing);
    expect(service.state.errorMessage, contains('audio device'));
  });

  test('a warning before load is cleared from status once it loads', () async {
    await service.open('a.mp4');
    backend.emitError('Could not open/initialize audio device -> no sound.');
    expect(service.state.status, PlaybackStatus.error);
    backend.emitDuration(const Duration(seconds: 10));
    expect(service.state.status, PlaybackStatus.paused);
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
      final received = <PlaybackStatus>[];
      final sub = service.status.listen(received.add);
      // Emitted synchronously, before any microtask has run.
      backend.emitPlaying(value: true);
      await pumpEventQueue();
      await sub.cancel();
      expect(received, [PlaybackStatus.loading, PlaybackStatus.playing]);
    });

    test('states replays the current state first, then changes', () async {
      await service.open('a.mp4');
      final received = <PlaybackStatus>[];
      final sub = service.status.listen(received.add);
      await pumpEventQueue();
      backend.emitPlaying(value: true);
      await pumpEventQueue();
      await sub.cancel();
      expect(received, [PlaybackStatus.loading, PlaybackStatus.playing]);
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
}
