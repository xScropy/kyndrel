import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/features/playback/widgets/seek_bar.dart';
import 'package:kyndrel/features/playback/widgets/transport_controls.dart';
import 'package:kyndrel/features/playback/widgets/volume_control.dart';
import 'package:material_ui/material_ui.dart';

/// Seek bar plus the three button groups from the reference screenshots.
///
/// [rightActions] come from other features (subtitles, speed...) and are
/// wired by the app shell, which keeps features free of cross-imports.
class BottomControls extends StatelessWidget {
  const new({required this.rightActions, super.key});

  final List<Widget> rightActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
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
          const SeekBarRow(),
          const SizedBox(height: 6),
          SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VolumeControl(),
                      ControlButton(
                        key: Key('download'),
                        icon: Icons.download_outlined,
                        tooltip: 'Download (coming in a later version)',
                      ),
                    ],
                  ),
                ),
                const TransportControls(),
                Align(
                  alignment: Alignment.centerRight,
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
