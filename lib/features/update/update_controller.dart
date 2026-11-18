import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/app_info.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/features/update/update_checker.dart';
import 'package:path/path.dart' as p;

/// Where the update flow is (task 5.6).
sealed class UpdateStatus {
  const new();
}

final class UpdateIdle extends UpdateStatus {
  const new();
}

final class UpdateChecking extends UpdateStatus {
  const new();
}

final class UpdateUpToDate extends UpdateStatus {
  const new();
}

final class UpdateAvailable extends UpdateStatus {
  const new(this.info);
  final UpdateInfo info;
}

final class UpdateDownloading extends UpdateStatus {
  const new(this.info, this.progress);
  final UpdateInfo info;
  final double progress;
}

final class UpdateFailed extends UpdateStatus {
  const new(this.message);
  final String message;
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final checker = UpdateChecker(
    repository: Uri.parse(appRepository).path.substring(1),
    currentVersion: appVersion,
  );
  ref.onDispose(checker.close);
  return checker;
});

/// Starts the downloaded Windows installer. It closes Kyndrel through the
/// Restart Manager, installs silently and starts the new version.
typedef InstallerRunner = Future<void> Function(String installerPath);

final installerRunnerProvider = Provider<InstallerRunner>((ref) {
  return (path) async {
    await Process.start(path, const [
      '/SILENT',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
      '/NOCANCEL',
    ], mode: ProcessStartMode.detached);
    // Saves resume points (onClose handlers) before the installer asks.
    await ref.read(windowServiceProvider).close();
  };
});

/// Whether this platform installs in place (Windows) or opens the download.
final updateInstallsInPlaceProvider = Provider<bool>(
  (ref) => Platform.isWindows,
);

final updateProvider = NotifierProvider<UpdateController, UpdateStatus>(
  UpdateController.new,
);

class UpdateController extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() => const UpdateIdle();

  /// Asks GitHub. A [manual] check reports "up to date" and failures; the
  /// automatic one on start stays quiet unless there is an update.
  Future<void> check({bool manual = false}) async {
    if (state is UpdateChecking || state is UpdateDownloading) return;
    state = const UpdateChecking();
    try {
      final info = await ref.read(updateCheckerProvider).check();
      state = info != null
          ? UpdateAvailable(info)
          : (manual ? const UpdateUpToDate() : const UpdateIdle());
    } on Exception catch (e) {
      debugPrint('update check failed: $e');
      state = manual ? UpdateFailed('$e') : const UpdateIdle();
    }
  }

  void dismiss() => state = const UpdateIdle();

  /// Windows: download the installer and run it. Elsewhere: open the
  /// installer download (or the release page) in the browser.
  Future<void> install() async {
    final s = state;
    if (s is! UpdateAvailable) return;
    final info = s.info;
    final url = info.downloadUrl;
    if (url == null || !ref.read(updateInstallsInPlaceProvider)) {
      await ref.read(externalOpenerProvider)('${url ?? info.pageUrl}');
      return;
    }
    state = UpdateDownloading(info, 0);
    try {
      final dir = await Directory.systemTemp.createTemp('kyndrel-update');
      final file = File(p.join(dir.path, p.basename(url.path)));
      await ref
          .read(updateCheckerProvider)
          .download(
            url,
            file,
            onProgress: (v) => state = UpdateDownloading(info, v),
          );
      await ref.read(installerRunnerProvider)(file.path);
    } on Exception catch (e) {
      state = UpdateFailed('$e');
    }
  }

  Future<void> openReleasePage() async {
    final s = state;
    final info = switch (s) {
      UpdateAvailable(:final info) || UpdateDownloading(:final info) => info,
      _ => null,
    };
    if (info != null) {
      await ref.read(externalOpenerProvider)('${info.pageUrl}');
    }
  }
}
