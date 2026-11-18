import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One entry in the phone's "More" sheet: an existing control button and
/// a short label under it.
typedef MoreAction = ({Widget button, String label});

/// "More" on phones (task 6.5): the controls that don't fit the bottom
/// bar, in a sheet. Each is the same button as on desktop, so its popover
/// or panel opens as usual.
class MoreButton extends StatelessWidget {
  const new({required this.actions, super.key});

  final List<MoreAction> Function(BuildContext context) actions;

  @override
  Widget build(BuildContext context) => ControlButton(
    key: const Key('more'),
    icon: Icons.more_horiz,
    tooltip: context.l10n.more,
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: KyndrelColors.panel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            key: const Key('more-sheet'),
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final a in actions(context))
                SizedBox(
                  width: 84,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      a.button,
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KyndrelColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
