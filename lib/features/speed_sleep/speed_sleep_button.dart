import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/speed_sleep/sleep_timer.dart';
import 'package:kyndrel/features/speed_sleep/speed_options.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Speed changes from the popover and `[` / `]`.
abstract final class SpeedActions {
  static Future<void> set(WidgetRef ref, double rate) async {
    await ref.read(playerServiceProvider).setRate(rate);
    ref.read(osdProvider.notifier).show('Speed ${SpeedOptions.label(rate)}');
  }

  static Future<void> stepUp(WidgetRef ref) =>
      set(ref, SpeedOptions.stepUp(ref.read(playerServiceProvider).state.rate));

  static Future<void> stepDown(WidgetRef ref) => set(
    ref,
    SpeedOptions.stepDown(ref.read(playerServiceProvider).state.rate),
  );
}

/// Bottom-right button showing the rate (and the sleep countdown), opening
/// the "Speed & sleep" popover above it (tasks 2.1–2.3).
class SpeedSleepButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(
      playbackStateProvider.select((s) => s.value?.rate ?? 1),
    );
    final sleep = ref.watch(sleepTimerProvider);
    return Popover(
      align: PopoverAlign.right,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('speed-button'),
        icon: Icons.speed,
        tooltip: context.l10n.speedAndSleep,
        active: rate != 1 || sleep != null,
        onPressed: toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatRate(rate)),
            if (sleep != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.bedtime, size: 16, color: KyndrelColors.accent),
              if (sleep.remaining != null) ...[
                const SizedBox(width: 2),
                Text(
                  formatDuration(sleep.remaining!),
                  key: const Key('sleep-remaining'),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      contentBuilder: (context, close) => const SpeedSleepPanel(),
    );
  }
}

class SpeedSleepPanel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(
      playbackStateProvider.select((s) => s.value?.rate ?? 1),
    );
    final sleep = ref.watch(sleepTimerProvider);
    final isCustom = !SpeedOptions.values.contains(rate);

    // Phones stack the two lists (6.5); wider screens put them side by side.
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final divider = narrow
        ? const Divider(height: 32, color: KyndrelColors.panelBorder)
        : const VerticalDivider(width: 32, color: KyndrelColors.panelBorder);
    final children = [
      SizedBox(
        width: narrow ? null : 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.playbackSpeedHeader,
              style: KyndrelTheme.sectionLabel,
            ),
            const SizedBox(height: 8),
            for (final v in SpeedOptions.values)
              PopoverOption(
                key: Key('speed-$v'),
                label: SpeedOptions.label(v),
                selected: rate == v,
                onTap: () => unawaited(SpeedActions.set(ref, v)),
                trailing: v == SpeedOptions.normal ? const _DefaultTag() : null,
              ),
            const SizedBox(height: 8),
            _CustomSpeedField(rate: isCustom ? rate : null),
          ],
        ),
      ),
      divider,
      SizedBox(
        width: narrow ? null : 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.sleepTimerHeader,
              style: KyndrelTheme.sectionLabel,
            ),
            const SizedBox(height: 8),
            for (final option in SleepOption.all)
              PopoverOption(
                key: Key('sleep-${option.label}'),
                label: option.label,
                selected: sleep?.option == option,
                onTap: () => unawaited(
                  ref.read(sleepTimerProvider.notifier).select(option),
                ),
                trailing: sleep?.option == option
                    ? Text(
                        sleep!.remaining != null
                            ? formatDuration(sleep.remaining!)
                            : sleep.episodesLeft > 0
                            ? 'after ${sleep.episodesLeft} more'
                            : 'on',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KyndrelColors.accent,
                        ),
                      )
                    : null,
              ),
            if (sleep != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.sleepCancelHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: KyndrelColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
    if (narrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DefaultTag extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: const Color(0x1FFFFFFF),
      ),
      child: Text(
        context.l10n.defaultBadge,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: KyndrelColors.sectionLabel,
        ),
      ),
    );
  }
}

/// Free-form speed (0.1–4×), task 2.2.
class _CustomSpeedField extends ConsumerStatefulWidget {
  const new({this.rate});

  final double? rate;

  @override
  ConsumerState<_CustomSpeedField> createState() => _CustomSpeedFieldState();
}

class _CustomSpeedFieldState extends ConsumerState<_CustomSpeedField> {
  late final _controller = TextEditingController(
    text: widget.rate == null ? '' : '${widget.rate}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final v = SpeedOptions.parseCustom(_controller.text);
    setState(() => _error = v == null ? '0.1 – 4' : null);
    if (v != null) unawaited(SpeedActions.set(ref, v));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('custom-speed'),
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        labelText: context.l10n.custom,
        hintText: 'e.g. 1.1',
        errorText: _error,
        suffixText: '×',
        suffixIcon: IconButton(
          tooltip: context.l10n.apply,
          icon: const Icon(Icons.check, size: 18),
          onPressed: _apply,
        ),
      ),
      onSubmitted: (_) => _apply(),
    );
  }
}
