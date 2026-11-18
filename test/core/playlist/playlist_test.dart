import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/utils/natural_sort.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late PlayerService service;
  late ProviderContainer container;

  setUp(() {
    backend = FakePlayerBackend();
    service = PlayerService(backend);
    container = ProviderContainer(
      overrides: [playerServiceProvider.overrideWithValue(service)],
    )..listen(playlistProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  PlaylistController pl() => container.read(playlistProvider.notifier);
  PlaylistState st() => container.read(playlistProvider);
  List<String> opened() => backend.calls
      .where((c) => c.startsWith('open('))
      .map((c) => c.substring(5, c.indexOf(',')))
      .toList();

  Future<void> finish() async {
    backend
      ..emitDuration(const Duration(minutes: 20))
      ..emitPosition(const Duration(minutes: 20))
      ..emitCompleted(value: true);
    await pumpEventQueue();
  }

  test('natural sort', () {
    final names = ['Ep 10.mkv', 'ep 2.mkv', 'Ep 1.mkv', 'Ep 2b.mkv']
      ..sort(compareNatural);
    expect(names, ['Ep 1.mkv', 'ep 2.mkv', 'Ep 2b.mkv', 'Ep 10.mkv']);
  });

  test('plays the start item and advances on completion', () async {
    await pl().openAll(['a', 'b', 'c'], start: 1);
    expect(opened(), ['b']);
    await finish();
    expect(opened(), ['b', 'c']);
    expect(st().current, 2);
    await finish();
    expect(opened(), ['b', 'c'], reason: 'end of queue, repeat off');
  });

  test('repeat all wraps, repeat one replays', () async {
    await pl().openAll(['a', 'b']);
    pl().cycleRepeat();
    expect(st().repeat, QueueRepeat.all);
    await finish();
    await finish();
    expect(opened(), ['a', 'b', 'a']);
    pl().cycleRepeat();
    expect(st().repeat, QueueRepeat.one);
    backend.calls.clear();
    await finish();
    expect(backend.calls, ['seek(0)', 'play']);
  });

  test('next, and previous restarts after 3 s', () async {
    await pl().openAll(['a', 'b', 'c']);
    await pl().next();
    backend
      ..emitDuration(const Duration(minutes: 1))
      ..emitPosition(const Duration(seconds: 30));
    backend.calls.clear();
    await pl().previous();
    expect(backend.calls, ['seek(0)']);
    backend.emitPosition(const Duration(seconds: 1));
    await pl().previous();
    expect(opened().last, 'a');
  });

  test('stopAfterCurrent holds the queue once (sleep timer)', () async {
    await pl().openAll(['a', 'b', 'c']);
    pl().setStopAfterCurrent(value: true);
    await finish();
    expect(opened(), ['a']);
    expect(st().stopAfterCurrent, isFalse);
  });

  test(
    'shuffle keeps the current item first and visits every item once',
    () async {
      pl().random = Random(42);
      await pl().openAll(['a', 'b', 'c', 'd', 'e'], start: 2);
      pl().toggleShuffle();
      expect(st().order.first, 2);
      expect(st().order.toSet(), {0, 1, 2, 3, 4});
      for (var i = 0; i < 4; i++) {
        await finish();
      }
      expect(opened().toSet(), {'a', 'b', 'c', 'd', 'e'});
      expect(opened(), hasLength(5));
    },
  );

  test('reorder and remove keep the current item', () async {
    await pl().openAll(['a', 'b', 'c', 'd'], start: 1);
    pl().reorder(1, 3);
    expect(st().items, ['a', 'c', 'd', 'b']);
    expect(st().current, 3);
    pl().reorder(0, 2);
    expect(st().items, ['c', 'd', 'a', 'b']);
    expect(st().current, 3);
    pl().remove(0);
    expect(st().items, ['d', 'a', 'b']);
    expect(st().current, 2);
    pl().remove(2);
    expect(st().current, isNull);
  });

  test('enqueue appends, or plays when idle', () async {
    await pl().enqueue(['x']);
    expect(opened(), ['x']);
    await pl().enqueue(['y', 'z']);
    expect(st().items, ['x', 'y', 'z']);
    expect(opened(), ['x']);
  });

  test('openFolder queues media files in natural order', () async {
    final dir = Directory.systemTemp.createTempSync('kyndrel_pl');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final n in [
      'Show E10.mkv',
      'Show E2.mkv',
      'Show E1.mp4',
      'notes.txt',
      'cover.jpg',
    ]) {
      File(p.join(dir.path, n)).writeAsStringSync('x');
    }
    await pl().openFolder(dir.path, startWith: p.join(dir.path, 'Show E2.mkv'));
    expect(st().items.map(p.basename), [
      'Show E1.mp4',
      'Show E2.mkv',
      'Show E10.mkv',
    ]);
    expect(st().current, 1);
  });
}
