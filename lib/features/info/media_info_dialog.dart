import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:material_ui/material_ui.dart';

/// The "i" button's dialog: container, codecs, bitrate, resolution, HDR,
/// audio channels, file size, with a copy button.
Future<void> showMediaInfoDialog(BuildContext context, WidgetRef ref) async {
  final service = ref.read(playerServiceProvider);
  final info = await service.mediaInfo();
  if (!context.mounted) return;
  final sections = MediaInfoSections.from(info, tracks: service.tracks);
  await showDialog<void>(
    context: context,
    builder: (context) => MediaInfoDialog(sections: sections),
  );
}

/// Grouped, human-readable rows built from mpv properties.
class MediaInfoSections {
  new(this.sections);

  factory from(Map<String, String> p, {TrackState tracks = TrackState.empty}) {
    String? v(String k) => p[k];
    final w = v('video-params/w');
    final h = v('video-params/h');
    final gamma = v('video-params/gamma');
    final hdr = switch (gamma) {
      'pq' => 'HDR10 (PQ)',
      'hlg' => 'HLG',
      null => null,
      _ => v('video-params/primaries') == 'bt.2020' ? 'SDR (BT.2020)' : 'SDR',
    };
    String trackLine(MediaTrack t) => [
      languageName(t.language),
      ?t.codec,
      if (t.channels != null) '${t.channels} ch',
      if (t.isExternal) 'external',
      if (t.isForced) 'forced',
      if (t.title != null && t.title!.isNotEmpty) '"${t.title}"',
    ].join(', ');
    final duration = double.tryParse(v('duration') ?? '');
    return MediaInfoSections({
      'File': {
        'Name': v('filename'),
        'Path': v('path'),
        'Container': v('file-format'),
        'Size': _bytes(v('file-size')),
        'Duration': duration == null
            ? null
            : formatDuration(Duration(milliseconds: (duration * 1000).round())),
      },
      'Video': {
        'Codec': v('video-codec'),
        'Resolution': w != null && h != null ? '$w × $h' : null,
        'Frame rate': _fps(v('container-fps')),
        'Bitrate': _bitrate(v('video-bitrate')),
        'Pixel format': v('video-params/pixelformat'),
        'Colour': [
          v('video-params/primaries'),
          v('video-params/colormatrix'),
        ].nonNulls.join(' / ').ifEmpty,
        'Dynamic range': hdr,
        'Hardware decoding': switch (v('hwdec-current')) {
          null || '' || 'no' => 'Off',
          final d => d,
        },
      },
      'Audio': {
        'Codec': v('audio-codec'),
        'Channels': [
          v('audio-params/channel-count'),
          if (v('audio-params/hr-channels') case final l?) '($l)',
        ].nonNulls.join(' ').ifEmpty,
        'Sample rate': _hz(v('audio-params/samplerate')),
        'Bitrate': _bitrate(v('audio-bitrate')),
      },
      'Tracks': {
        for (final (i, t) in tracks.audio.indexed)
          'Audio ${i + 1}': trackLine(t),
        for (final (i, t) in tracks.subtitles.indexed)
          'Subtitle ${i + 1}': trackLine(t),
        'Chapters': switch (v('chapters')) {
          null || '0' => null,
          final c => c,
        },
      },
    });
  }

  final Map<String, Map<String, String?>> sections;

  String toPlainText() => sections.entries
      .map(
        (s) => [
          s.key,
          for (final r in s.value.entries)
            if (r.value != null) '  ${r.key}: ${r.value}',
        ].join('\n'),
      )
      .join('\n\n');

  static String? _bytes(String? s) {
    final n = int.tryParse(s ?? '');
    if (n == null) return null;
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = n.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String? _bitrate(String? s) {
    final n = double.tryParse(s ?? '');
    if (n == null || n <= 0) return null;
    return n >= 1e6
        ? '${(n / 1e6).toStringAsFixed(1)} Mb/s'
        : '${(n / 1e3).round()} kb/s';
  }

  static String? _fps(String? s) {
    final n = double.tryParse(s ?? '');
    if (n == null) return null;
    return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 3)} fps';
  }

  static String? _hz(String? s) {
    final n = int.tryParse(s ?? '');
    if (n == null) return null;
    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)} kHz';
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

class MediaInfoDialog extends StatelessWidget {
  const new({required this.sections, super.key});

  final MediaInfoSections sections;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Media info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in sections.sections.entries)
                        if (s.value.values.any((v) => v != null)) ...[
                          const SizedBox(height: 12),
                          Text(
                            s.key.toUpperCase(),
                            style: KyndrelTheme.sectionLabel,
                          ),
                          const SizedBox(height: 6),
                          for (final r in s.value.entries)
                            if (r.value != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        r.key,
                                        style: const TextStyle(
                                          color: KyndrelColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: SelectableText(r.value!)),
                                  ],
                                ),
                              ),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const Key('media-info-copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: sections.toPlainText()),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(content: Text('Copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
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
