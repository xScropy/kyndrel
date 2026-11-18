import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/platform/device_media.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's videos, or why there are none.
@immutable
class DeviceVideosState {
  const new({this.videos = const [], this.denied = false, this.asked = false});

  final List<DeviceVideo> videos;

  /// The user said no to the permission prompt.
  final bool denied;

  /// Whether we have tried with permission (else show the button).
  final bool asked;

  /// Folder names, the biggest first.
  List<String> get folders {
    final counts = <String, int>{};
    for (final v in videos) {
      counts[v.folder] = (counts[v.folder] ?? 0) + 1;
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }
}

/// "On this phone" (task 6.2): MediaStore videos grouped by folder.
class DeviceVideosController extends AsyncNotifier<DeviceVideosState> {
  @override
  Future<DeviceVideosState> build() async {
    final media = ref.watch(deviceMediaProvider);
    if (media == null) return const DeviceVideosState();
    // Without the permission this is empty: show the button.
    final videos = await media.videos();
    return DeviceVideosState(videos: videos, asked: videos.isNotEmpty);
  }

  /// Asks for access, then lists.
  Future<void> allow() async {
    final media = ref.read(deviceMediaProvider);
    if (media == null) return;
    final granted = await media.requestVideoAccess();
    state = AsyncData(
      granted
          ? DeviceVideosState(videos: await media.videos(), asked: true)
          : const DeviceVideosState(denied: true, asked: true),
    );
  }
}

final deviceVideosProvider =
    AsyncNotifierProvider<DeviceVideosController, DeviceVideosState>(
      DeviceVideosController.new,
    );

/// Start-screen section: folder chips and the folder's videos. Tapping a
/// video plays it with the rest of its folder queued.
class DeviceVideosSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DeviceVideosSection> createState() =>
      _DeviceVideosSectionState();
}

class _DeviceVideosSectionState extends ConsumerState<DeviceVideosSection> {
  String? _folder;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(deviceMediaProvider) == null) return const SizedBox.shrink();
    final l = context.l10n;
    final state = ref.watch(deviceVideosProvider).value;
    if (state == null) return const SizedBox.shrink();

    Widget body;
    if (!state.asked || state.denied) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.denied)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.phoneVideosDenied,
                style: const TextStyle(color: KyndrelColors.textSecondary),
              ),
            ),
          OutlinedButton.icon(
            key: const Key('device-videos-allow'),
            onPressed: () =>
                unawaited(ref.read(deviceVideosProvider.notifier).allow()),
            icon: const Icon(Icons.video_library_outlined),
            label: Text(l.showPhoneVideos),
          ),
        ],
      );
    } else if (state.videos.isEmpty) {
      body = Text(
        l.phoneVideosNone,
        style: const TextStyle(color: KyndrelColors.textSecondary),
      );
    } else {
      final folder = _folder;
      final shown = folder == null
          ? state.videos
          : state.videos.where((v) => v.folder == folder).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(l.allFolders, null, state.videos.length),
                for (final f in state.folders)
                  _chip(f, f, state.videos.where((v) => v.folder == f).length),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, v) in shown.take(50).indexed)
            ListTile(
              key: Key('device-video-$i'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.movie_outlined),
              title: Text(
                v.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (v.duration > Duration.zero) formatDuration(v.duration),
                  if (folder == null) v.folder,
                ].join(' · '),
              ),
              onTap: () => unawaited(_play(shown, i)),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.onThisPhone, style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _chip(String label, String? folder, int count) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      key: Key('device-folder-${folder ?? '*'}'),
      label: Text('$label · $count'),
      selected: _folder == folder,
      onSelected: (_) => setState(() => _folder = folder),
    ),
  );

  Future<void> _play(List<DeviceVideo> list, int index) async {
    for (final v in list) {
      v.file.remember();
    }
    await ref.read(playlistProvider.notifier).openAll([
      for (final v in list) v.file.uri,
    ], start: index);
  }
}
