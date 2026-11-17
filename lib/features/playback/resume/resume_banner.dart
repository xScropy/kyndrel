import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/playback/resume/resume_controller.dart';
import 'package:material_ui/material_ui.dart';

/// "Resume from 12:34?" with Resume / Start over. Disappears by itself
/// after [visibleFor].
class ResumeBanner extends ConsumerStatefulWidget {
  const new({super.key});

  static const visibleFor = Duration(seconds: 10);

  @override
  ConsumerState<ResumeBanner> createState() => _ResumeBannerState();
}

class _ResumeBannerState extends ConsumerState<ResumeBanner> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(resumeControllerProvider, (_, offer) {
      _timer?.cancel();
      if (offer != null) {
        _timer = Timer(
          ResumeBanner.visibleFor,
          ref.read(resumeControllerProvider.notifier).dismiss,
        );
      }
    });
    final offer = ref.watch(resumeControllerProvider);
    if (offer == null) return const SizedBox.shrink();
    final controller = ref.read(resumeControllerProvider.notifier);
    return Container(
      key: const Key('resume-banner'),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      decoration: KyndrelTheme.panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, color: KyndrelColors.accent, size: 20),
          const SizedBox(width: 10),
          Text('Resume from ${formatDuration(offer.position)}?'),
          const SizedBox(width: 12),
          TextButton(
            key: const Key('resume-start-over'),
            onPressed: controller.dismiss,
            child: const Text(
              'Start over',
              style: TextStyle(color: KyndrelColors.textSecondary),
            ),
          ),
          FilledButton(
            key: const Key('resume-accept'),
            onPressed: () => unawaited(controller.accept()),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}
