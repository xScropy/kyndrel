import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/features/subtitles/opensubtitles/opensubtitles_client.dart';
import 'package:kyndrel/features/subtitles/subtitle_search_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Right pane: "Looking for subtitles…" then OpenSubtitles results.
class OnlineResultsView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnlineResultsView> createState() => _OnlineResultsViewState();
}

class _OnlineResultsViewState extends ConsumerState<OnlineResultsView> {
  @override
  void initState() {
    super.initState();
    // Providers can't change during build; search right after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(subtitleSearchProvider.notifier).searchForCurrent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(subtitleSearchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ONLINE', style: KyndrelTheme.sectionLabel),
        const SizedBox(height: 8),
        Expanded(
          child: switch (search.status) {
            SearchStatus.idle || SearchStatus.searching => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Looking for subtitles...',
                    key: Key('subtitle-searching'),
                    style: TextStyle(color: KyndrelColors.textSecondary),
                  ),
                ],
              ),
            ),
            SearchStatus.failed => _Message(text: search.message ?? ''),
            SearchStatus.done when search.results.isEmpty => _Message(
              text: search.message ?? 'No subtitles found.',
            ),
            SearchStatus.done => ListView.builder(
              itemCount: search.results.length,
              itemBuilder: (context, i) => _ResultTile(
                result: search.results[i],
                applying: search.applyingFileId == search.results[i].fileId,
                applied: search.appliedFileIds.contains(
                  search.results[i].fileId,
                ),
              ),
            ),
          },
        ),
        if (search.status == SearchStatus.done && search.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              search.message!,
              style: const TextStyle(fontSize: 12, color: KyndrelColors.error),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      key: const Key('subtitle-search-message'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: KyndrelColors.textSecondary),
    ),
  );
}

class _ResultTile extends ConsumerWidget {
  const new({
    required this.result,
    required this.applying,
    required this.applied,
  });

  final SubtitleResult result;
  final bool applying;
  final bool applied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = [
      languageName(result.language),
      if (result.rating > 0) '★ ${result.rating.toStringAsFixed(1)}',
      '↓ ${result.downloadCount}',
      if (result.hashMatch) 'Matches file',
      if (result.hearingImpaired) 'SDH',
      if (result.machineTranslated) 'Machine-translated',
    ].join('  ·  ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: applying
          ? null
          : () => unawaited(
              ref.read(subtitleSearchProvider.notifier).apply(result),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.release.isEmpty ? result.fileName : result.release,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KyndrelColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (applying)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                applied ? Icons.check_circle : Icons.download,
                size: 18,
                color: applied
                    ? KyndrelColors.accent
                    : KyndrelColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
