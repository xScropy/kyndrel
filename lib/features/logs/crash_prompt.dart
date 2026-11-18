import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/app_info.dart';
import 'package:kyndrel/core/logging/crash_monitor.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/logs/log_viewer_page.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// After a crash, offers once to open a pre-filled GitHub issue (task 5.7,
/// opt-out in Settings › Advanced). Nothing is sent by Kyndrel itself.
Future<void> maybeOfferCrashReport(BuildContext context, WidgetRef ref) async {
  final monitor = ref.read(crashMonitorProvider);
  final report = monitor.previous;
  if (report == null || !ref.read(settingsProvider).offerCrashReports) return;
  monitor.dismissPrevious();
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('crash-dialog'),
      title: Text(context.l10n.crashTitle),
      content: Text(
        report.unexpectedExit
            ? context.l10n.crashBodyExit
            : context.l10n.crashBodyError,
      ),
      actions: [
        TextButton(
          key: const Key('crash-view-log'),
          onPressed: () => Navigator.pop(context, 'log'),
          child: Text(context.l10n.viewLog),
        ),
        TextButton(
          key: const Key('crash-dismiss'),
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.notNow),
        ),
        FilledButton(
          key: const Key('crash-report'),
          onPressed: () => Navigator.pop(context, 'report'),
          child: Text(context.l10n.crashReport),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'report':
      final url = crashIssueUrl(
        repository: Uri.parse(appRepository).path.substring(1),
        version: appVersion,
        report: report,
      );
      await ref.read(externalOpenerProvider)('$url');
    case 'log':
      await showLogViewer(context);
  }
}
