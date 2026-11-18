import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/window/window_app_bar.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:kyndrel/core/platform/open_external.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLogViewer(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LogViewerPage()));

/// The app log, newest at the bottom (task 5.7): filter by level, copy,
/// open the folder with the log files.
class LogViewerPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends ConsumerState<LogViewerPage> {
  LogLevel _min = LogLevel.info;
  StreamSubscription<LogRecord>? _sub;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _sub = ref.read(appLogProvider).changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  static Color _colour(LogLevel l) => switch (l) {
    LogLevel.error => KyndrelColors.error,
    LogLevel.warn => KyndrelColors.accent,
    LogLevel.info => KyndrelColors.textPrimary,
    LogLevel.debug => KyndrelColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(appLogProvider);
    final shown = log.records
        .where((r) => r.level.index >= _min.index)
        .toList();
    final dir = log.directory;
    return Scaffold(
      backgroundColor: KyndrelColors.background,
      appBar: WindowAppBar(
        title: Text(context.l10n.logTitle),
        actions: [
          DropdownButton<LogLevel>(
            key: const Key('log-level'),
            value: _min,
            underline: const SizedBox(),
            onChanged: (v) => setState(() => _min = v ?? _min),
            items: [
              for (final l in LogLevel.values)
                DropdownMenuItem(
                  value: l,
                  child: Text(context.l10n.logLevelAndUp(l.name)),
                ),
            ],
          ),
          IconButton(
            key: const Key('log-copy'),
            tooltip: context.l10n.logCopy,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: shown.map((r) => r.format()).join('\n')),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(context.l10n.logCopied)));
              }
            },
          ),
          if (dir != null)
            IconButton(
              key: const Key('log-folder'),
              tooltip: context.l10n.logOpenFolder,
              icon: const Icon(Icons.folder_open),
              onPressed: () =>
                  unawaited(ref.read(externalOpenerProvider)(dir.path)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: shown.isEmpty
          ? Center(child: Text(context.l10n.logEmpty))
          : SelectionArea(
              child: ListView.builder(
                key: const Key('log-list'),
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final r = shown[shown.length - 1 - i];
                  return Text(
                    r.format(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _colour(r.level),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
