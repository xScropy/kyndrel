import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/window/window_title_bar.dart';
import 'package:material_ui/material_ui.dart';

/// App bar for pages pushed over the player (Settings, Log): the window is
/// frameless, so these pages need the drag area and window buttons too.
class WindowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.title, this.actions = const [], super.key});

  final Widget title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(KyndrelTokens.titleBarHeight);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KyndrelColors.background,
      child: WindowTitleBar(
        child: Row(
          children: [
            const SizedBox(width: 4),
            if (Navigator.of(context).canPop()) const BackButton(),
            const SizedBox(width: 8),
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.titleLarge,
              child: title,
            ),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}
