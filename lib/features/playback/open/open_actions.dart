import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/osd.dart';

/// Ways to open media (task 1.11). Command-line arguments and "Open with"
/// arrive through `main.dart` / the platform channel and call [openSource].
abstract final class OpenActions {
  static const videoExtensions = [
    'mp4', 'm4v', 'mkv', 'webm', 'avi', 'mov', 'wmv', 'flv', 'mpg', 'mpeg',
    'ts', 'm2ts', 'mts', '3gp', 'ogv', 'vob', 'rmvb', 'divx', 'm3u8', //
    'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'wav',
  ];

  static Future<void> openSource(WidgetRef ref, String source) =>
      ref.read(playerServiceProvider).open(source);

  /// Shows the system file picker.
  static Future<void> pickFile(WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Video and audio',
          extensions: videoExtensions,
          uniformTypeIdentifiers: ['public.movie', 'public.audio'],
          mimeTypes: ['video/*', 'audio/*'],
        ),
        XTypeGroup(label: 'All files'),
      ],
    );
    if (file != null) await openSource(ref, file.path);
  }

  /// Opens a URL or path from the clipboard. Returns false if the clipboard
  /// doesn't hold one.
  static Future<bool> pasteFromClipboard(WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!looksOpenable(text)) {
      ref.read(osdProvider.notifier).show('Clipboard has no link or path');
      return false;
    }
    await openSource(ref, text);
    return true;
  }

  /// A URL with a scheme (`https://`, `rtsp://`, `file://`...) or an
  /// absolute path, on one line.
  static bool looksOpenable(String text) {
    if (text.isEmpty || text.contains('\n')) return false;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme && uri.scheme.length > 1) {
      return uri.hasAuthority || uri.scheme == 'file' || uri.path.isNotEmpty;
    }
    return text.startsWith('/') ||
        text.startsWith('~') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(text) ||
        text.startsWith(r'\\');
  }
}
