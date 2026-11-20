import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/playback_state.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:kyndrel/features/music/disc.dart';
import 'package:kyndrel/features/music/now_playing.dart';
import 'package:kyndrel/features/music/waves.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What plays when the file is music (task 7.6): a turning record with the
/// cover art, the title, artist and album, and waves that follow the
/// loudness. The player's usual controls stay on screen below it.
class MusicPlayerView extends ConsumerStatefulWidget {
  const new({super.key});

  /// Room left for the player's top bar.
  static const topBar = 60.0;

  /// Room left for the controls along the bottom.
  static const bottomBar = 150.0;

  @override
  ConsumerState<MusicPlayerView> createState() => _MusicPlayerViewState();
}

class _MusicPlayerViewState extends ConsumerState<MusicPlayerView> {
  late final ControlsVisibility _visibility;
  // One listener (the waves); it stops when they go.
  late final Stream<AudioLevel> _levels = ref
      .read(playerServiceProvider)
      .levels();

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(controlsVisibilityProvider.notifier);
    // Music has nothing to look at under the controls: they stay. Changed
    // after this frame (providers can't change during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibility.lock(this);
    });
  }

  @override
  void dispose() {
    _visibility.unlock(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowPlayingProvider);
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
    );
    final waves = ref.watch(settingsProvider.select((s) => s.musicWaves));
    final still = ref.watch(settingsProvider.select((s) => s.reduceMotion));
    final padding = MediaQuery.paddingOf(context);
    final l = context.l10n;

    Widget texts({required CrossAxisAlignment align}) => Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          now?.title ?? '',
          key: const Key('music-title'),
          maxLines: 2,
          textAlign: align == CrossAxisAlignment.center
              ? TextAlign.center
              : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        if (now?.artist != null) ...[
          const SizedBox(height: 6),
          Text(
            now!.artist!,
            key: const Key('music-artist'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, color: KyndrelColors.accent),
          ),
        ],
        if (now?.album != null) ...[
          const SizedBox(height: 2),
          Text(
            now!.album!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: KyndrelColors.textSecondary),
          ),
        ],
      ],
    );

    Widget wavesBand(double height) => SizedBox(
      height: height,
      child: waves
          ? MusicWaves(levels: _levels, playing: playing, gentle: still)
          : null,
    );

    return Stack(
      key: const Key('music-view'),
      fit: StackFit.expand,
      children: [
        // A warm glow from the cover's side.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 1.1,
              colors: [KyndrelColors.musicGlow, KyndrelColors.background],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            padding.top + MusicPlayerView.topBar,
            24,
            padding.bottom + MusicPlayerView.bottomBar,
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 700 && c.maxWidth > c.maxHeight;
              if (wide) {
                final disc = math.min(c.maxHeight * 0.9, c.maxWidth * 0.4);
                return Row(
                  children: [
                    SizedBox.square(
                      dimension: disc,
                      child: SpinningDisc(
                        playing: playing,
                        cover: now?.cover,
                        still: still,
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          texts(align: CrossAxisAlignment.start),
                          const SizedBox(height: 24),
                          wavesBand(math.min(140, c.maxHeight * 0.3)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              final disc = [
                c.maxWidth * 0.78,
                c.maxHeight * 0.55,
                380.0,
              ].reduce(math.min);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: disc,
                    child: SpinningDisc(
                      playing: playing,
                      cover: now?.cover,
                      still: still,
                    ),
                  ),
                  const SizedBox(height: 20),
                  texts(align: CrossAxisAlignment.center),
                  const SizedBox(height: 8),
                  Flexible(child: wavesBand(math.min(110, c.maxHeight * 0.18))),
                ],
              );
            },
          ),
        ),
        PositionedDirectional(
          top: padding.top + MusicPlayerView.topBar - 4,
          end: 12,
          child: ControlButton(
            key: const Key('music-minimize'),
            icon: Icons.keyboard_arrow_down,
            tooltip: l.musicMinimize,
            onPressed: ref.read(musicMinimizedProvider.notifier).minimize,
          ),
        ),
      ],
    );
  }
}

/// The song playing, as a bar under the library (task 7.6): tap to open
/// the player again.
class MiniPlayer extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    if (now == null) return const SizedBox.shrink();
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
    );
    final progress = ref.watch(
      playbackStateProvider.select((s) {
        final v = s.value;
        if (v == null || v.duration <= Duration.zero) return 0.0;
        return (v.position.inMilliseconds / v.duration.inMilliseconds).clamp(
          0.0,
          1.0,
        );
      }),
    );
    final hasNext = ref.watch(playlistProvider.select((q) => q.hasNext));
    final service = ref.read(playerServiceProvider);
    final l = context.l10n;
    final cover = now.cover;
    return Material(
      key: const Key('mini-player'),
      color: KyndrelColors.surface,
      child: InkWell(
        onTap: ref.read(musicMinimizedProvider.notifier).expand,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              color: KyndrelColors.accent,
              backgroundColor: KyndrelColors.track,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      KyndrelTokens.badgeRadius,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: cover == null
                          ? const ColoredBox(
                              color: KyndrelColors.rowActive,
                              child: Icon(
                                Icons.music_note,
                                color: KyndrelColors.accent,
                              ),
                            )
                          : Image.file(
                              File(cover),
                              fit: BoxFit.cover,
                              cacheWidth: 128,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          now.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (now.artist != null)
                          Text(
                            now.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: KyndrelColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ControlButton(
                    key: const Key('mini-play-pause'),
                    icon: playing ? Icons.pause : Icons.play_arrow,
                    tooltip: playing ? l.pause : l.play,
                    onPressed: () => unawaited(service.playOrPause()),
                  ),
                  if (hasNext)
                    ControlButton(
                      key: const Key('mini-next'),
                      icon: Icons.skip_next,
                      tooltip: l.musicNext,
                      onPressed: () =>
                          unawaited(ref.read(playlistProvider.notifier).next()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
