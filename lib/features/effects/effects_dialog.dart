import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/effects.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/player_service.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Picture quality (4.6) and audio effects (4.7). Saved in settings; the
/// app shell applies them to the engine.
Future<void> showEffectsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const EffectsDialog());

class EffectsDialog extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: const DefaultTabController(
          length: 2,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  tabs: [
                    Tab(key: Key('tab-video'), text: 'Video'),
                    Tab(key: Key('tab-audio'), text: 'Audio'),
                  ],
                ),
                SizedBox(height: 12),
                Flexible(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(child: VideoEffectsSection()),
                      SingleChildScrollView(child: AudioEffectsSection()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _update(WidgetRef ref, AppSettings Function(AppSettings) f) =>
    unawaited(ref.read(settingsProvider.notifier).update(f));

/// Picture settings (task 4.6), also used on the settings page.
class VideoEffectsSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PictureAdjustments(),
        const SizedBox(height: 16),
        const Text('QUALITY', style: KyndrelTheme.sectionLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in VideoPreset.values)
              ChoiceChip(
                key: Key('preset-${p.name}'),
                label: Text(p.label),
                selected: s.videoPreset == p,
                onSelected: (_) =>
                    _update(ref, (x) => x.copyWith(videoPreset: p)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Higher quality uses more GPU. Applies to GPU rendering only.',
          style: TextStyle(fontSize: 11, color: KyndrelColors.textSecondary),
        ),
        SwitchListTile(
          key: const Key('deband'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Deband'),
          subtitle: const Text('Smooths banding in skies and gradients'),
          value: s.deband,
          onChanged: (v) => _update(ref, (x) => x.copyWith(deband: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('HDR on SDR screens'),
          subtitle: const Text('Tone mapping curve'),
          trailing: DropdownButton<String>(
            key: const Key('tone-mapping'),
            value: s.toneMapping,
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final e in toneMappingChoices.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => _update(ref, (x) => x.copyWith(toneMapping: v)),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hardware decoding'),
          trailing: DropdownButton<String>(
            key: const Key('hwdec'),
            value: hwdecChoices.containsKey(s.hwdec) ? s.hwdec : 'auto-safe',
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final e in hwdecChoices.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => _update(ref, (x) => x.copyWith(hwdec: v)),
          ),
        ),
      ],
    );
  }
}

/// Equalizer and loudness (task 4.7), also used on the settings page.
class AudioEffectsSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final preset = Equalizer.presetName(s.equalizer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('EQUALIZER', style: KyndrelTheme.sectionLabel),
            const Spacer(),
            DropdownButton<String>(
              key: const Key('eq-preset'),
              value: preset,
              hint: const Text('Custom'),
              dropdownColor: KyndrelColors.surface,
              items: [
                for (final name in Equalizer.presets.keys)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (v) => _update(
                ref,
                (x) => x.copyWith(equalizer: Equalizer.presets[v]),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              for (var i = 0; i < Equalizer.frequencies.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${s.equalizer[i] > 0 ? '+' : ''}'
                        '${s.equalizer[i].round()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            key: Key('eq-$i'),
                            min: -Equalizer.maxGain,
                            max: Equalizer.maxGain,
                            divisions: 24,
                            value: s.equalizer[i],
                            onChanged: (v) => _update(
                              ref,
                              (x) => x.copyWith(
                                equalizer: [...x.equalizer]..[i] = v,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _hz(Equalizer.frequencies[i]),
                        style: const TextStyle(
                          fontSize: 10,
                          color: KyndrelColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('LOUDNESS', style: KyndrelTheme.sectionLabel),
        RadioGroup<Normalization>(
          groupValue: s.normalization,
          onChanged: (v) => _update(ref, (x) => x.copyWith(normalization: v)),
          child: Column(
            children: [
              for (final n in Normalization.values)
                RadioListTile<Normalization>(
                  key: Key('norm-${n.name}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: n,
                  title: Text(n.label),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _hz(int f) => f >= 1000 ? '${f ~/ 1000}k' : '$f';
}

/// Brightness, contrast, saturation, gamma and hue, −100…100 (task 8.8).
/// For this session, like VLC's adjustments; reset puts them back.
class PictureAdjustmentsController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  Future<void> set(String name, int value) async {
    state = {...state, name: value};
    await ref.read(playerServiceProvider).setPictureAdjustment(name, value);
  }

  Future<void> reset() async {
    final service = ref.read(playerServiceProvider);
    for (final n in PlayerService.pictureAdjustments) {
      await service.setPictureAdjustment(n, 0);
    }
    state = const {};
  }
}

final pictureAdjustmentsProvider =
    NotifierProvider<PictureAdjustmentsController, Map<String, int>>(
      PictureAdjustmentsController.new,
    );

class PictureAdjustments extends ConsumerWidget {
  const new({super.key});

  static const _labels = {
    'brightness': 'Brightness',
    'contrast': 'Contrast',
    'saturation': 'Saturation',
    'gamma': 'Gamma',
    'hue': 'Hue',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(pictureAdjustmentsProvider);
    final c = ref.read(pictureAdjustmentsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('ADJUSTMENTS', style: KyndrelTheme.sectionLabel),
            ),
            TextButton(
              key: const Key('adjust-reset'),
              onPressed: values.isEmpty ? null : () => unawaited(c.reset()),
              child: const Text('Reset'),
            ),
          ],
        ),
        for (final name in PlayerService.pictureAdjustments)
          Row(
            children: [
              SizedBox(width: 96, child: Text(_labels[name]!)),
              Expanded(
                child: Slider(
                  key: Key('adjust-$name'),
                  min: -100,
                  max: 100,
                  divisions: 40,
                  value: (values[name] ?? 0).toDouble(),
                  activeColor: KyndrelColors.accent,
                  onChanged: (v) => unawaited(c.set(name, v.round())),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${values[name] ?? 0}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
