import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:kyndrel/features/playback/widgets/transport_controls.dart';
import 'package:kyndrel/features/playback/widgets/volume_control.dart';
import 'package:material_ui/material_ui.dart';

/// Seek bar plus the three button groups from the reference screenshots.
///
/// [rightActions] come from other features (subtitles, speed...) and are
/// wired by the app shell, which keeps features free of cross-imports.
class BottomControls extends StatelessWidget {
  const new({
    required this.rightActions,
    this.leftActions = const [],
    this.compact = false,
    super.key,
  });

  /// Phone layout (task 6.5): no volume slider (phones have swipes and
  /// volume keys), tighter padding, and the side groups share the row
  /// with the transport instead of overlapping it.
  final bool compact;

  final List<Widget> rightActions;

  /// After the volume group (the download button, task 4.3).
  final List<Widget> leftActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 16, 12, 8)
          : const EdgeInsets.fromLTRB(20, 24, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timelines and transport keep tape direction in RTL locales
          // (Material bidirectionality guidance); the side groups mirror.
          // The seek bar relays out and repaints on every position tick.
          // Tight constraints make it a relayout boundary and the
          // RepaintBoundary its own layer, so the rest of the bar is left
          // alone (task 5.4).
          const SizedBox(
            width: double.infinity,
            height: SeekBarRow.height,
            child: RepaintBoundary(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SeekBarRow(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (compact)
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    // Small phones: the buttons shrink to fit rather than
                    // overflow (320 dp leaves about 60 px a side).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: leftActions,
                      ),
                    ),
                  ),
                  const Directionality(
                    textDirection: TextDirection.ltr,
                    child: TransportControls(),
                  ),
                  Expanded(
                    // Small phones: the buttons shrink to fit rather than
                    // overflow (320 dp leaves about 60 px a side).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: rightActions,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Directionality(
                          textDirection: TextDirection.ltr,
                          child: VolumeControl(),
                        ),
                        ...leftActions,
                      ],
                    ),
                  ),
                  const Directionality(
                    textDirection: TextDirection.ltr,
                    child: TransportControls(),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: rightActions,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
