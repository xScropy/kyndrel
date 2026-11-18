import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/up_next.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:path/path.dart' as p;

enum QueueRepeat { off, all, one }

/// The play queue (task 3.1).
@immutable
class PlaylistState {
  const new({
    this.items = const [],
    this.current,
    this.shuffle = false,
    this.repeat = QueueRepeat.off,
    this.order = const [],
    this.stopAfterCurrent = false,
  });

  /// Sources in queue order (what the panel shows).
  final List<String> items;

  /// Index in [items] of what's playing, or null.
  final int? current;
  final bool shuffle;
  final QueueRepeat repeat;

  /// Play order as indices into [items]; the identity unless shuffled.
  final List<int> order;

  /// Don't advance when the current item ends (sleep timer).
  final bool stopAfterCurrent;

  static const empty = PlaylistState();

  bool get hasNext => _step(1) != null;
  bool get hasPrevious => _step(-1) != null;

  /// Index in [items] that's [delta] steps away in play order, honouring
  /// repeat-all wrap-around.
  int? _step(int delta) {
    final c = current;
    if (c == null || order.isEmpty) return null;
    final pos = order.indexOf(c);
    var next = pos + delta;
    if (next < 0 || next >= order.length) {
      if (repeat != QueueRepeat.all || order.length < 2) return null;
      next %= order.length;
    }
    return order[next];
  }

  PlaylistState copyWith({
    List<String>? items,
    int? Function()? current,
    bool? shuffle,
    QueueRepeat? repeat,
    List<int>? order,
    bool? stopAfterCurrent,
  }) => PlaylistState(
    items: items ?? this.items,
    current: current != null ? current() : this.current,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    order: order ?? this.order,
    stopAfterCurrent: stopAfterCurrent ?? this.stopAfterCurrent,
  );
}

class PlaylistController extends Notifier<PlaylistState> {
  /// "Previous" restarts the current item when it's past this point.
  static const restartThreshold = Duration(seconds: 3);

  static const mediaExtensions = {
    '.mp4', '.m4v', '.mkv', '.webm', '.avi', '.mov', '.wmv', '.flv', '.mpg',
    '.mpeg', '.ts', '.m2ts', '.mts', '.3gp', '.ogv', '.vob', '.rmvb', //
    '.mp3', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wav',
  };

  Random _random = Random();

  @visibleForTesting
  // ignore: avoid_setters_without_getters, test hook
  set random(Random r) => _random = r;

  @override
  PlaylistState build() {
    final sub = ref
        .watch(playerServiceProvider)
        .completions
        .listen((_) => unawaited(_onCompleted()));
    ref.onDispose(sub.cancel);
    return PlaylistState.empty;
  }

  /// Replaces the queue with [sources] and plays [start].
  Future<void> openAll(List<String> sources, {int start = 0}) async {
    if (sources.isEmpty) return;
    ref.read(upNextProvider.notifier).cancel();
    final s = start.clamp(0, sources.length - 1);
    state = PlaylistState(
      items: List.unmodifiable(sources),
      repeat: state.repeat,
      shuffle: state.shuffle,
      order: _makeOrder(sources.length, s, shuffle: state.shuffle),
      current: s,
    );
    await _play(s);
  }

  /// Plays one source (file picker, drop, command line). An episode also
  /// queues the following episodes from its folder (task 3.2), if enabled.
  Future<void> open(String source) async {
    if (_autoNext && !source.contains('://') && File(source).existsSync()) {
      final episodes = episodesFrom(source, listMedia(p.dirname(source)));
      if (episodes.length > 1) {
        await openAll(episodes);
        return;
      }
    }
    await openAll([source]);
  }

  int get _upNextSeconds {
    try {
      return ref.read(settingsProvider).upNextSeconds;
    } on Object {
      // No settings in some tests: move on straight away.
      return 0;
    }
  }

  bool get _autoNext {
    try {
      return ref.read(settingsProvider).autoPlayNextEpisode;
    } on Object {
      // No settings in some tests: default on.
      return true;
    }
  }

  /// Queues every media file in [directory] (natural order) and plays the
  /// first, or [startWith] if given.
  Future<void> openFolder(String directory, {String? startWith}) async {
    final files = listMedia(directory);
    if (files.isEmpty) return;
    final start = startWith == null ? 0 : max(0, files.indexOf(startWith));
    await openAll(files, start: start);
  }

  /// Media files directly inside [directory]: episodes in episode order,
  /// then the rest in natural order.
  static List<String> listMedia(String directory) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    return sortEpisodes(
      dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((f) => mediaExtensions.contains(p.extension(f).toLowerCase())),
    );
  }

  /// Adds [sources] to the end of the queue; starts playing if idle.
  Future<void> enqueue(List<String> sources) async {
    if (sources.isEmpty) return;
    if (state.items.isEmpty) {
      await openAll(sources);
      return;
    }
    final items = [...state.items, ...sources];
    final added = [for (var i = state.items.length; i < items.length; i++) i];
    state = state.copyWith(
      items: List.unmodifiable(items),
      order: [
        ...state.order,
        ...(state.shuffle ? (added..shuffle(_random)) : added),
      ],
    );
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.items.length) return;
    ref.read(upNextProvider.notifier).cancel();
    state = state.copyWith(current: () => index, stopAfterCurrent: false);
    await _play(index);
  }

  Future<void> next() async {
    final n = state._step(1);
    if (n != null) await playAt(n);
  }

  /// Restarts the current item if it's been playing a while, otherwise goes
  /// to the previous one.
  Future<void> previous() async {
    final service = ref.read(playerServiceProvider);
    final prev = state._step(-1);
    if (service.state.position > restartThreshold || prev == null) {
      await service.seek(Duration.zero);
      return;
    }
    await playAt(prev);
  }

  void remove(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items]..removeAt(index);
    final order = [
      for (final i in state.order)
        if (i > index) i - 1 else if (i < index) i,
    ];
    final c = state.current;
    state = state.copyWith(
      items: List.unmodifiable(items),
      order: order,
      current: () => c == null || c == index
          ? null
          : c > index
          ? c - 1
          : c,
    );
  }

  /// Moves an item (drag to reorder). [newIndex] is the final position.
  void reorder(int oldIndex, int newIndex) {
    final n = state.items.length;
    if (oldIndex < 0 || oldIndex >= n) return;
    final to = newIndex.clamp(0, n - 1);
    if (to == oldIndex) return;
    final items = [...state.items];
    final moved = items.removeAt(oldIndex);
    items.insert(to, moved);
    int map(int i) {
      if (i == oldIndex) return to;
      if (oldIndex < to && i > oldIndex && i <= to) return i - 1;
      if (oldIndex > to && i >= to && i < oldIndex) return i + 1;
      return i;
    }

    final c = state.current;
    state = state.copyWith(
      items: List.unmodifiable(items),
      order: state.shuffle
          ? state.order.map(map).toList()
          : List.generate(n, (i) => i),
      current: () => c == null ? null : map(c),
    );
  }

  void toggleShuffle() {
    final shuffle = !state.shuffle;
    state = state.copyWith(
      shuffle: shuffle,
      order: _makeOrder(
        state.items.length,
        state.current ?? 0,
        shuffle: shuffle,
      ),
    );
  }

  void cycleRepeat() => state = state.copyWith(
    repeat: QueueRepeat
        .values[(state.repeat.index + 1) % QueueRepeat.values.length],
  );

  // ignore: reads better at call sites
  void setStopAfterCurrent({required bool value}) =>
      state = state.copyWith(stopAfterCurrent: value);

  void clear() =>
      state = PlaylistState(repeat: state.repeat, shuffle: state.shuffle);

  List<int> _makeOrder(int length, int first, {required bool shuffle}) {
    final order = List.generate(length, (i) => i);
    if (!shuffle || length < 2) return order;
    order
      ..remove(first)
      ..shuffle(_random)
      ..insert(0, first);
    return order;
  }

  Future<void> _play(int index) =>
      ref.read(playerServiceProvider).open(state.items[index]);

  Future<void> _onCompleted() async {
    if (state.current == null) return;
    if (state.stopAfterCurrent) {
      state = state.copyWith(stopAfterCurrent: false);
      return;
    }
    if (state.repeat == QueueRepeat.one) {
      // play() restarts a completed file from the beginning.
      await ref.read(playerServiceProvider).play();
      return;
    }
    final n = state._step(1);
    final seconds = _upNextSeconds;
    if (n != null && seconds > 0) {
      ref
          .read(upNextProvider.notifier)
          .start(index: n, source: state.items[n], seconds: seconds);
      return;
    }
    await next();
  }
}

final playlistProvider = NotifierProvider<PlaylistController, PlaylistState>(
  PlaylistController.new,
);
