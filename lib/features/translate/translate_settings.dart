import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Translation provider and key (task 4.2) for the settings page.
class TranslateSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Subtitle translation',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Service'),
          trailing: DropdownButton<String>(
            key: const Key('settings-translate-provider'),
            value: s.translateProvider,
            dropdownColor: KyndrelColors.surface,
            items: const [
              DropdownMenuItem(value: 'claude', child: Text('Claude')),
              DropdownMenuItem(value: 'deepl', child: Text('DeepL')),
              DropdownMenuItem(
                value: 'google',
                child: Text('Google Translate'),
              ),
            ],
            onChanged: (v) =>
                updateSettings(ref, (x) => x.copyWith(translateProvider: v)),
          ),
        ),
        SettingsTextField(
          key: const Key('settings-translate-key'),
          label: switch (s.translateProvider) {
            'deepl' => 'DeepL API key',
            'google' => 'Google Cloud API key',
            _ => 'Anthropic API key',
          },
          secret: true,
          value: switch (s.translateProvider) {
            'deepl' => s.deeplApiKey,
            'google' => s.googleTranslateApiKey,
            _ => s.anthropicApiKey,
          },
          onChanged: (v) => updateSettings(
            ref,
            (x) => switch (x.translateProvider) {
              'deepl' => x.copyWith(deeplApiKey: v.trim()),
              'google' => x.copyWith(googleTranslateApiKey: v.trim()),
              _ => x.copyWith(anthropicApiKey: v.trim()),
            },
          ),
        ),
      ],
    );
  }
}
