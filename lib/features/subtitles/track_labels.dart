import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:path/path.dart' as p;

/// `English`, `English · SDH`, `Arabic (external)`; the file name for an
/// external track without a language.
String trackLabel(MediaTrack t) {
  final hasLang = t.language != null && t.language!.isNotEmpty;
  final base = hasLang
      ? languageName(t.language)
      : t.isExternal && t.externalFilename != null
      ? p.basename(t.externalFilename!)
      : 'Track ${t.id}';
  final title = t.title;
  // mpv titles external tracks with their file name; that's noise here.
  final isFileName =
      t.externalFilename != null && title == p.basename(t.externalFilename!);
  final parts = [
    base,
    if (title != null &&
        title.isNotEmpty &&
        title != base &&
        hasLang &&
        !isFileName)
      title,
  ];
  return parts.join(' · ');
}

/// Small tags shown next to a track: `PGS`, `External`, `Forced`, `5.1`.
List<String> trackTags(MediaTrack t) => [
  if (t.isImageSubtitle)
    if (t.codec == 'dvd_subtitle') 'VobSub' else 'PGS',
  if (t.isExternal) 'External',
  if (t.isForced) 'Forced',
  if (t.isDefault && t.type == MediaTrackType.audio) 'Default',
  ?_channels(t),
];

String? _channels(MediaTrack t) {
  if (t.channels == null || t.type != MediaTrackType.audio) return null;
  final label = switch (t.channels!) {
    1 => 'Mono',
    2 => 'Stereo',
    6 => '5.1',
    8 => '7.1',
    final n => '$n ch',
  };
  // Don't repeat what the track title already says.
  return (t.title ?? '').contains(label) ? null : label;
}
