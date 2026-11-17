import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/features/cast/cast_controller.dart';
import 'package:kyndrel/features/cast/cast_device.dart';
import 'package:material_ui/material_ui.dart';

/// Cast icon and device picker (task 4.4).
class CastButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(castProvider.select((s) => s.active));
    return Popover(
      align: PopoverAlign.right,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('cast'),
        icon: active == null ? Icons.cast : Icons.cast_connected,
        tooltip: active == null ? 'Cast' : 'Casting to ${active.name}',
        active: active != null,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => const CastPanel(),
    );
  }
}

class CastPanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CastPanel> createState() => _CastPanelState();
}

class _CastPanelState extends ConsumerState<CastPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(castProvider).active == null) {
        unawaited(ref.read(castProvider.notifier).scan());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(castProvider);
    final c = ref.read(castProvider.notifier);
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('CAST', style: KyndrelTheme.sectionLabel),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: KyndrelColors.sectionLabel),
                ),
                child: const Text(
                  'BETA',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: KyndrelColors.sectionLabel,
                  ),
                ),
              ),
              const Spacer(),
              if (s.active == null)
                IconButton(
                  key: const Key('cast-rescan'),
                  tooltip: 'Search again',
                  iconSize: 18,
                  onPressed: s.scanning ? null : () => unawaited(c.scan()),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (s.active != null) ...[
            Text('Playing on ${s.active!.name}', key: const Key('cast-active')),
            if (s.transcoding)
              const Text(
                'Converted on the fly for this device (seeking restarts '
                'the stream).',
                style: TextStyle(
                  fontSize: 11,
                  color: KyndrelColors.textSecondary,
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('cast-stop'),
              onPressed: () => unawaited(c.stop()),
              icon: const Icon(Icons.cast, size: 18),
              label: const Text('Stop casting'),
            ),
          ] else ...[
            if (s.scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Looking for devices…'),
                  ],
                ),
              )
            else if (s.devices.isEmpty)
              const Text(
                'No Chromecast or DLNA devices found on this network.',
                key: Key('cast-none'),
                style: TextStyle(color: KyndrelColors.textSecondary),
              ),
            for (final d in s.devices)
              ListTile(
                key: Key('cast-device-${d.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  d.kind == CastKind.chromecast ? Icons.cast : Icons.tv,
                ),
                title: Text(d.name),
                subtitle: Text(
                  d.kind == CastKind.chromecast ? 'Chromecast' : 'DLNA',
                ),
                trailing: s.connecting == d
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: s.connecting == null
                    ? () => unawaited(c.castTo(d))
                    : null,
              ),
          ],
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: KyndrelColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown over the video while casting.
class CastingBanner extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(castProvider.select((s) => s.active));
    if (active == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cast_connected,
            size: 56,
            color: KyndrelColors.accent,
          ),
          const SizedBox(height: 12),
          Text(
            'Playing on ${active.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
