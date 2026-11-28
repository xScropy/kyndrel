import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/features/library/music_library.dart';
import 'package:kyndrel/features/library/video_library.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The start screen's sections (task 7.4).
enum LibrarySection { home, videos, music, browse }

class LibrarySectionController extends Notifier<LibrarySection> {
  @override
  LibrarySection build() => LibrarySection.home;

  // ignore: use_setters_to_change_properties, reads better at call sites
  void show(LibrarySection section) => state = section;
}

final librarySectionProvider =
    NotifierProvider<LibrarySectionController, LibrarySection>(
      LibrarySectionController.new,
    );

/// When nothing is playing: Home (open, continue watching, recent), the
/// device's videos and its music. A bar along the bottom on phones, a
/// rail on the side on wider screens.
class LibraryShell extends ConsumerWidget {
  const new({
    required this.home,
    this.browse,
    this.bottom,
    this.topInset = topBar,
    super.key,
  });

  /// The Home section (`LibraryHome`).
  final Widget home;

  /// The Browse section (folders and network servers, task 8.7); passed
  /// in by the app, which composes features.
  final Widget? browse;

  /// Along the bottom, above the section bar: the mini player (7.6).
  final Widget? bottom;

  /// Room left at the top for the player's top bar.
  final double topInset;

  /// Height of the player's top bar, which overlays this screen.
  static const topBar = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(librarySectionProvider);
    final controller = ref.read(librarySectionProvider.notifier);
    final l = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final top = MediaQuery.paddingOf(context).top + topInset;
    // "Pure black" changes the theme's backgrounds (task 8.8).
    final background = Theme.of(context).scaffoldBackgroundColor;
    final bar = background == KyndrelColors.black
        ? KyndrelColors.black
        : KyndrelColors.surface;

    final content = switch (section) {
      LibrarySection.home => home,
      LibrarySection.videos => Padding(
        padding: EdgeInsets.only(top: top),
        child: const VideoLibrary(),
      ),
      // Its own section, separate from the videos (task 7.5).
      LibrarySection.music => Padding(
        padding: EdgeInsets.only(top: top),
        child: const MusicLibrary(),
      ),
      LibrarySection.browse => Padding(
        padding: EdgeInsets.only(top: top),
        child: browse ?? const SizedBox.shrink(),
      ),
    };
    final destinations = [
      (LibrarySection.home, Icons.home_outlined, Icons.home, l.libraryHome),
      (
        LibrarySection.videos,
        Icons.video_library_outlined,
        Icons.video_library,
        l.libraryVideos,
      ),
      (
        LibrarySection.music,
        Icons.library_music_outlined,
        Icons.library_music,
        l.libraryMusic,
      ),
      if (browse != null)
        (
          LibrarySection.browse,
          Icons.folder_open_outlined,
          Icons.folder_open,
          l.libraryBrowse,
        ),
    ];

    if (wide) {
      final rail = Row(
        children: [
          Padding(
            padding: EdgeInsets.only(top: top),
            child: NavigationRail(
              key: const Key('library-rail'),
              backgroundColor: background,
              selectedIndex: section.index,
              onDestinationSelected: (i) =>
                  controller.show(LibrarySection.values[i]),
              labelType: NavigationRailLabelType.all,
              indicatorColor: KyndrelColors.rowActive,
              selectedIconTheme: const IconThemeData(
                color: KyndrelColors.accent,
              ),
              destinations: [
                for (final (s, icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon, key: Key('section-${s.name}')),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
          ),
          // 80 + 2: an even width left, so centred text sits on whole
          // pixels (crisp on 1× screens).
          const VerticalDivider(
            width: 2,
            thickness: 1,
            color: KyndrelColors.panelBorder,
          ),
          Expanded(child: content),
        ],
      );
      if (bottom == null) return rail;
      return Column(
        children: [
          Expanded(child: rail),
          bottom!,
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: content),
        ?bottom,
        NavigationBar(
          key: const Key('library-bar'),
          height: 64,
          backgroundColor: bar,
          indicatorColor: KyndrelColors.rowActive,
          selectedIndex: section.index,
          onDestinationSelected: (i) =>
              controller.show(LibrarySection.values[i]),
          destinations: [
            for (final (s, icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon, key: Key('section-${s.name}')),
                selectedIcon: Icon(selected, color: KyndrelColors.accent),
                label: label,
              ),
          ],
        ),
      ],
    );
  }
}
