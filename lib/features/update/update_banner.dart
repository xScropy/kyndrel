import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/update/update_controller.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// "Kyndrel X is available" (task 5.6). Also starts the automatic check a
/// few seconds after launch when Settings › Advanced › Check for updates
/// is on.
class UpdateBanner extends ConsumerStatefulWidget {
  const new({super.key});

  /// Wait after start so the check never competes with opening a file.
  static const startDelay = Duration(seconds: 5);

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (ref.read(settingsProvider).checkForUpdates) {
      _timer = Timer(
        UpdateBanner.startDelay,
        () => unawaited(ref.read(updateProvider.notifier).check()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(updateProvider);
    final l = context.l10n;
    final controller = ref.read(updateProvider.notifier);
    final (info, progress) = switch (status) {
      UpdateAvailable(:final info) => (info, null),
      UpdateDownloading(:final info, :final progress) => (info, progress),
      _ => (null, null),
    };
    if (info == null) return const SizedBox.shrink();
    final inPlace = ref.watch(updateInstallsInPlaceProvider);
    return Material(
      key: const Key('update-banner'),
      color: KyndrelColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KyndrelColors.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 8, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_alt, color: KyndrelColors.accent),
            const SizedBox(width: 12),
            if (progress != null)
              SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.updateDownloading((progress * 100).round())),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: KyndrelColors.track,
                    ),
                  ],
                ),
              )
            else ...[
              Text(l.updateAvailable('${info.version}')),
              const SizedBox(width: 12),
              TextButton(
                key: const Key('update-notes'),
                onPressed: () => unawaited(controller.openReleasePage()),
                child: Text(l.updateWhatsNew),
              ),
              FilledButton(
                key: const Key('update-install'),
                onPressed: () => unawaited(controller.install()),
                child: Text(
                  inPlace && info.downloadUrl != null
                      ? l.updateInstall
                      : l.updateDownload,
                ),
              ),
              IconButton(
                key: const Key('update-later'),
                tooltip: l.updateLater,
                icon: const Icon(Icons.close, size: 18),
                onPressed: controller.dismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
