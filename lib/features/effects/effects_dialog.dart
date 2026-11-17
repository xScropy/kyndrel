import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/effects.dart';
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
                  child: TabBarView(children: [_VideoTab(), _AudioTab()]),
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

class _VideoTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return ListView(
      children: [
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

class _AudioTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final preset = Equalizer.presetName(s.equalizer);
    return ListView(
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
