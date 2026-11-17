import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/metadata/media_details.dart';
import 'package:kyndrel/core/metadata/metadata_service.dart';
import 'package:kyndrel/core/metadata/tmdb_client.dart';
import 'package:kyndrel/core/utils/episode_parser.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:material_ui/material_ui.dart';

/// Manual override for a file's title, year and TMDB match (task 3.4).
Future<void> showEditDetailsDialog(BuildContext context, String source) =>
    showDialog<void>(
      context: context,
      builder: (_) => EditDetailsDialog(source: source),
    );

class EditDetailsDialog extends ConsumerStatefulWidget {
  const new({required this.source, super.key});

  final String source;

  @override
  ConsumerState<EditDetailsDialog> createState() => _EditDetailsDialogState();
}

class _EditDetailsDialogState extends ConsumerState<EditDetailsDialog> {
  late final TextEditingController _title;
  late final TextEditingController _year;
  late bool _episode;
  List<MediaDetails> _results = const [];
  String? _message;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final parsed = parseMediaTitle(widget.source);
    final current = ref.read(mediaDetailsProvider(widget.source)).value;
    _title = TextEditingController(text: current?.title ?? parsed.title);
    _year = TextEditingController(
      text: '${current?.year ?? parsed.year ?? ''}',
    );
    _episode = parseEpisode(widget.source) != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final r = await ref
          .read(metadataServiceProvider)
          .search(
            _title.text,
            episode: _episode,
            year: int.tryParse(_year.text),
          );
      setState(() {
        _results = r;
        _message = r.isEmpty ? 'Nothing found.' : null;
      });
    } on TmdbException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save(MediaDetails d) async {
    await ref.read(metadataServiceProvider).setManual(widget.source, d);
    ref.invalidate(mediaDetailsProvider(widget.source));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ep = parseEpisode(widget.source);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: const Key('details-title'),
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      onSubmitted: (_) => unawaited(_search()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('details-year'),
                      controller: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Movie'),
                    selected: !_episode,
                    onSelected: (_) => setState(() => _episode = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(ep == null ? 'TV show' : 'TV · ${ep.code}'),
                    selected: _episode,
                    onSelected: (_) => setState(() => _episode = true),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('details-search'),
                    onPressed: _searching ? null : () => unawaited(_search()),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search TMDB'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_message != null)
                Text(
                  _message!,
                  style: const TextStyle(color: KyndrelColors.textSecondary),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in _results)
                      ListTile(
                        key: Key('details-result-${r.tmdbId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 40,
                          height: 60,
                          child: r.posterUrl == null
                              ? const Icon(Icons.movie_outlined)
                              : Image.network(
                                  MediaDetails.imageUrl(
                                    r.posterPath!,
                                    size: 'w92',
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.movie_outlined),
                                ),
                        ),
                        title: Text(r.title),
                        subtitle: Text(
                          [
                            if (r.year != null) '${r.year}',
                            if (r.overview != null && r.overview!.isNotEmpty)
                              r.overview!,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => unawaited(_save(r)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(metadataServiceProvider)
                          .forget(widget.source);
                      ref.invalidate(mediaDetailsProvider(widget.source));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('details-save'),
                    onPressed: () => unawaited(
                      _save(
                        MediaDetails(
                          kind: _episode ? MediaKind.episode : MediaKind.movie,
                          title: _title.text.trim(),
                          year: int.tryParse(_year.text.trim()),
                          season: _episode ? ep?.season : null,
                          episode: _episode ? ep?.episode : null,
                        ),
                      ),
                    ),
                    child: const Text('Save as typed'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
