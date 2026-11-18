import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/playlist/up_next.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// "Up next" card with the countdown, Play now and Cancel.
class UpNextCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(upNextProvider);
    if (next == null) return const SizedBox.shrink();
    final l = context.l10n;
    final t = parseMediaTitle(next.source);
    final controller = ref.read(upNextProvider.notifier);
    return Container(
      key: const Key('up-next'),
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyndrelColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KyndrelColors.panelBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.upNext, style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          Text(
            [t.title, ?t.episode].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l.upNextIn(next.secondsLeft),
            key: const Key('up-next-countdown'),
            style: const TextStyle(color: KyndrelColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('up-next-cancel'),
                onPressed: controller.cancel,
                child: Text(l.upNextCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('up-next-play'),
                onPressed: () => unawaited(controller.playNow()),
                child: Text(l.upNextPlayNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
