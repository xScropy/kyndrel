import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/core/utils/languages.dart';
import 'package:kyndrel/features/translate/translate_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Target languages offered in the popover.
const translateLanguages = [
  'en', 'ar', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'tr', 'fa', 'ur', 'hi', //
  'id', 'ja', 'ko', 'zh', 'nl', 'pl', 'sv', 'uk', 'he', 'el',
];

/// The translate icon and its popover (task 4.2).
class TranslateButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translateProvider);
    return Popover(
      align: PopoverAlign.right,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('translate'),
        icon: Icons.translate,
        tooltip: 'Translate subtitles',
        active: t.busy || t.status == TranslateStatus.done,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => const TranslatePanel(),
    );
  }
}

class TranslatePanel extends ConsumerWidget {
  const new({super.key});

  static const providerNames = {
    'claude': 'Claude',
    'deepl': 'DeepL',
    'google': 'Google Translate',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translateProvider);
    final settings = ref.watch(settingsProvider);
    final hasTrack = ref.watch(
      trackStateProvider.select((s) => s.value?.subtitleId != null),
    );
    final controller = ref.read(translateProvider.notifier);
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('TRANSLATE SUBTITLES', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          Text(
            hasTrack
                ? 'Adds a translated second line under the current track.'
                : 'Turn on a subtitle track first (S).',
            style: const TextStyle(
              fontSize: 12,
              color: KyndrelColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            key: const Key('translate-target'),
            isExpanded: true,
            value: translateLanguages.contains(settings.translateTarget)
                ? settings.translateTarget
                : 'en',
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final l in translateLanguages)
                DropdownMenuItem(value: l, child: Text(languageName(l))),
            ],
            onChanged: t.busy
                ? null
                : (l) => unawaited(
                    ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(translateTarget: l)),
                  ),
          ),
          Text(
            'Using ${providerNames[settings.translateProvider] ?? '?'} '
            '(change in Settings)',
            style: const TextStyle(
              fontSize: 11,
              color: KyndrelColors.sectionLabel,
            ),
          ),
          const SizedBox(height: 12),
          if (t.status == TranslateStatus.reading)
            const LinearProgressIndicator()
          else if (t.status == TranslateStatus.translating)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: t.total == 0 ? null : t.done / t.total,
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.done} / ${t.total} lines',
                  key: const Key('translate-progress'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          if (t.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t.message!,
                key: const Key('translate-message'),
                style: TextStyle(
                  fontSize: 12,
                  color: t.status == TranslateStatus.failed
                      ? KyndrelColors.error
                      : KyndrelColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (t.status == TranslateStatus.done)
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(playerServiceProvider)
                        .selectSecondarySubtitle(null),
                  ),
                  child: const Text('Hide'),
                ),
              if (t.busy)
                TextButton(
                  key: const Key('translate-cancel'),
                  onPressed: controller.cancel,
                  child: const Text('Cancel'),
                )
              else
                FilledButton(
                  key: const Key('translate-start'),
                  onPressed: hasTrack
                      ? () => unawaited(
                          controller.start(settings.translateTarget),
                        )
                      : null,
                  child: const Text('Translate'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
