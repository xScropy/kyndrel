import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/intro_detector.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/intro_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The opening and credits of the file playing (task 8.9).
@immutable
class SkipRanges {
  const new({this.source, this.introStart, this.introEnd, this.creditsStart});

  final String? source;
  final Duration? introStart;
  final Duration? introEnd;
  final Duration? creditsStart;
}

/// Finds them: a saved mark for this file, else one marked by hand for the
/// show, else by comparing this episode's storyboard with another
/// episode's from the same folder once both exist.
class SkipIntroController extends Notifier<SkipRanges> {
  String? _source;
  Duration? _markStart;
  ProviderSubscription<Storyboard?>? _waiting;

  IntroRepository get _repo => ref.read(introRepositoryProvider);

  @override
  SkipRanges build() {
    final service = ref.watch(playerServiceProvider);
    final sub = service.states.listen((s) {
      final source = s.source;
      if (source == _source) return;
      _source = source;
      _markStart = null;
      _waiting?.close();
      _waiting = null;
      state = SkipRanges(source: source);
      if (source != null) unawaited(_lookUp(source));
    });
    ref.onDispose(() {
      _waiting?.close();
      unawaited(sub.cancel());
    });
    return const SkipRanges();
  }

  Future<void> _lookUp(String source) async {
    final own = await _repo.get(source);
    final episode = parseEpisode(source);
    final mark =
        own ??
        (episode == null
            ? null
            : await _repo.get(
                IntroRepository.showKey(episode.show, episode.season),
              ));
    if (_source != source) return;
    if (mark != null) {
      _apply(source, mark);
      return;
    }
    if (episode == null || !ref.read(settingsProvider).skipIntro) return;
    // Wait for this file's storyboard, then compare.
    _waiting = ref.listen(storyboardProvider, (_, board) {
      if (board == null || board.source != source || !board.complete) return;
      _waiting?.close();
      _waiting = null;
      unawaited(_detect(source, episode, board));
    }, fireImmediately: true);
  }

  void _apply(String source, IntroMark mark) {
    final duration = ref.read(playerServiceProvider).state.duration;
    final fromEnd = mark.creditsFromEndMs;
    state = SkipRanges(
      source: source,
      introStart: mark.introStartMs == null
          ? null
          : Duration(milliseconds: mark.introStartMs!),
      introEnd: mark.introEndMs == null
          ? null
          : Duration(milliseconds: mark.introEndMs!),
      creditsStart: fromEnd == null || duration <= Duration.zero
          ? null
          : duration - Duration(milliseconds: fromEnd),
    );
  }

  /// Another episode of the same show and season, beside this one, whose
  /// storyboard is ready.
  Storyboard? _sibling(String source, EpisodeInfo episode) {
    final cache = ref.read(appCacheDirProvider);
    final dir = Directory(p.dirname(source));
    if (!dir.existsSync()) return null;
    final others = <(int, Storyboard)>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path == source) continue;
      final e = parseEpisode(f.path);
      if (e == null ||
          e.show.toLowerCase() != episode.show.toLowerCase() ||
          e.season != episode.season) {
        continue;
      }
      final board = Storyboard.readSaved(cache, f.path);
      if (board == null || !board.levels.first.complete) continue;
      others.add(((e.episode - episode.episode).abs(), board));
    }
    others.sort((a, b) => a.$1.compareTo(b.$1));
    return others.firstOrNull?.$2;
  }

  Future<void> _detect(
    String source,
    EpisodeInfo episode,
    Storyboard board,
  ) async {
    final other = _sibling(source, episode);
    if (other == null) return;
    // The finest level both have.
    final level =
        board.levels.length > 1 &&
            other.levels.length > 1 &&
            board.levels[1].complete &&
            other.levels[1].complete
        ? 1
        : 0;
    final a = await storyboardHashes(board, level);
    final b = await storyboardHashes(other, level);
    final (ra, rb) = findIntroAndCredits(
      a,
      b,
      stepA: board.levels[level].spec.step,
      stepB: other.levels[level].spec.step,
    );
    for (final (src, r, length) in [
      (source, ra, board.duration),
      (other.source, rb, other.duration),
    ]) {
      if (r.isEmpty) continue;
      await _repo.save(
        src,
        introStart: r.introStart,
        introEnd: r.introEnd,
        creditsFromEnd: r.creditsStart == null
            ? null
            : length - r.creditsStart!,
      );
    }
    if (_source == source && !ra.isEmpty) {
      state = SkipRanges(
        source: source,
        introStart: ra.introStart,
        introEnd: ra.introEnd,
        creditsStart: ra.creditsStart,
      );
    }
  }

  /// Shift+M: the first press marks where the intro starts, the second
  /// where it ends; saved for the whole season (or this file).
  Future<void> mark() async {
    final s = ref.read(playerServiceProvider).state;
    final source = s.source;
    if (source == null) return;
    final osd = ref.read(osdProvider.notifier);
    final start = _markStart;
    if (start == null || s.position <= start) {
      _markStart = s.position;
      osd.show('Intro starts here — press again where it ends');
      return;
    }
    _markStart = null;
    final episode = parseEpisode(source);
    final key = episode == null
        ? source
        : IntroRepository.showKey(episode.show, episode.season);
    await _repo.save(
      key,
      introStart: start,
      introEnd: s.position,
      manual: true,
    );
    state = SkipRanges(
      source: source,
      introStart: start,
      introEnd: s.position,
      creditsStart: state.creditsStart,
    );
    osd.show(
      episode == null ? 'Intro saved' : 'Intro saved for ${episode.show}',
    );
  }
}

final skipIntroProvider = NotifierProvider<SkipIntroController, SkipRanges>(
  SkipIntroController.new,
);

/// "Skip intro" during the opening; "Next episode" (or "Skip credits")
/// during the credits. Chapters named Intro/Credits count too.
class SkipIntroButton extends ConsumerWidget {
  const new({super.key});

  /// The button goes this long before the end of the range.
  static const margin = Duration(seconds: 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsProvider.select((s) => s.skipIntro))) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final ranges = ref.watch(skipIntroProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final chapters =
        ref.watch(trackStateProvider.select((t) => t.value?.chapters)) ??
        const <Chapter>[];
    if (duration <= Duration.zero) return const SizedBox.shrink();

    // Chapters first: they are exact.
    var introStart = ranges.introStart;
    var introEnd = ranges.introEnd;
    var credits = ranges.creditsStart;
    for (var i = 0; i < chapters.length; i++) {
      final title = chapters[i].title ?? '';
      final end = i + 1 < chapters.length ? chapters[i + 1].start : duration;
      if (introChapter.hasMatch(title)) {
        introStart = chapters[i].start;
        introEnd = end;
      } else if (creditsChapter.hasMatch(title)) {
        credits = chapters[i].start;
      }
    }

    final service = ref.read(playerServiceProvider);
    String? label;
    VoidCallback? action;
    if (introStart != null &&
        introEnd != null &&
        position >= introStart &&
        position < introEnd - margin) {
      label = l.skipIntro;
      action = () => unawaited(service.seek(introEnd!));
    } else if (credits != null &&
        position >= credits &&
        position < duration - margin) {
      final queue = ref.watch(playlistProvider);
      final hasNext =
          queue.current != null && queue.current! + 1 < queue.items.length;
      if (hasNext) {
        label = l.nextEpisode;
        action = () => unawaited(ref.read(playlistProvider.notifier).next());
      } else {
        label = l.skipCredits;
        action = () => unawaited(service.seek(duration - margin));
      }
    }
    if (label == null) return const SizedBox.shrink();
    return FilledButton.icon(
      key: const Key('skip-intro'),
      style: FilledButton.styleFrom(
        backgroundColor: KyndrelColors.panel,
        foregroundColor: KyndrelColors.textPrimary,
        side: const BorderSide(color: KyndrelColors.panelBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      onPressed: action,
      icon: const Icon(Icons.skip_next),
      label: Text(label),
    );
  }
}
