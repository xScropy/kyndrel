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
    this.onOpenSettings,
    super.key,
  });

  /// Settings, at the bottom of the sidebar (task 9.16).
  final VoidCallback? onOpenSettings;

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

  /// The full sidebar from this width; a rail below it.
  static const sidebarFrom = 1000.0;

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

    // Harbor's sidebar on wide screens (task 9.16): the name at the top,
    // the sections as rounded rows, Settings at the bottom.
    if (MediaQuery.sizeOf(context).width >= sidebarFrom) {
      final shell = Row(
        children: [
          _Sidebar(
            // Below the window's drag strip and its shade.
            top:
                MediaQuery.paddingOf(context).top +
                KyndrelTokens.titleBarHeight,
            background: background,
            section: section,
            destinations: destinations,
            onSelect: controller.show,
            onOpenSettings: onOpenSettings,
          ),
          Expanded(child: content),
        ],
      );
      if (bottom == null) return shell;
      return Column(
        children: [
          Expanded(child: shell),
          bottom!,
        ],
      );
    }
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
              trailing: onOpenSettings == null
                  ? null
                  : IconButton(
                      key: const Key('section-settings'),
                      tooltip: l.settings,
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
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

class _Sidebar extends StatelessWidget {
  const new({
    required this.top,
    required this.background,
    required this.section,
    required this.destinations,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final double top;
  final Color background;
  final LibrarySection section;
  final List<(LibrarySection, IconData, IconData, String)> destinations;
  final ValueChanged<LibrarySection> onSelect;
  final VoidCallback? onOpenSettings;

  static const width = 240.0;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('library-sidebar'),
    width: width,
    decoration: BoxDecoration(
      color: background,
      border: const BorderDirectional(
        end: BorderSide(color: KyndrelColors.panelBorder),
      ),
    ),
    padding: EdgeInsets.fromLTRB(16, top, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 10, bottom: 28),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_fill,
                size: 32,
                color: KyndrelColors.accent,
              ),
              SizedBox(width: 10),
              Text(
                'Kyndrel',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        for (final (s, icon, selected, label) in destinations)
          _SidebarItem(
            key: Key('section-${s.name}'),
            icon: s == section ? selected : icon,
            label: label,
            selected: s == section,
            onTap: () => onSelect(s),
          ),
        const Spacer(),
        if (onOpenSettings != null)
          _SidebarItem(
            key: const Key('section-settings'),
            icon: Icons.settings_outlined,
            label: context.l10n.settings,
            selected: false,
            onTap: onOpenSettings!,
          ),
      ],
    ),
  );
}

class _SidebarItem extends StatefulWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected || _hover
        ? KyndrelColors.textPrimary
        : KyndrelColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            focusColor: KyndrelColors.focus,
            hoverColor: KyndrelColors.scrimClear,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              padding: const EdgeInsetsDirectional.only(start: 16),
              decoration: BoxDecoration(
                color: widget.selected
                    ? KyndrelColors.controlHover
                    : _hover
                    ? KyndrelColors.windowButtonHover.withValues(alpha: 0.06)
                    : KyndrelColors.scrimClear,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 22, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
