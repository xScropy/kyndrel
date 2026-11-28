import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/control_button.dart';
import 'package:kyndrel/core/ui/popover.dart';
import 'package:kyndrel/features/together/together_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Watch Together in the player's tools (task 9.11).
class TogetherButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(togetherProvider);
    return Popover(
      align: PopoverAlign.right,
      anchorBuilder: (context, toggle) => ControlButton(
        key: const Key('together'),
        icon: Icons.groups_outlined,
        tooltip: session == null
            ? 'Watch together'
            : 'Watch together · ${session.peers.length}',
        active: session != null,
        dot: session != null,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => const TogetherPanel(),
    );
  }
}

class TogetherPanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TogetherPanel> createState() => _TogetherPanelState();
}

class _TogetherPanelState extends ConsumerState<TogetherPanel> {
  final _invite = TextEditingController();
  final _chat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _invite.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on FormatException {
      _error =
          'That is not an invite. It looks like ABC123 or '
          'ABC123@192.168.1.5:7637.';
    } on Object catch (e) {
      _error = "Couldn't connect: $e";
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(togetherProvider);
    final relay = ref.watch(settingsProvider.select((s) => s.togetherRelay));
    final c = ref.read(togetherProvider.notifier);
    return Container(
      key: const Key('together-panel'),
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: KyndrelTheme.panelDecoration(),
      child: session == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('WATCH TOGETHER', style: KyndrelTheme.sectionLabel),
                const SizedBox(height: 6),
                const Text(
                  'Everyone opens the same film; play, pause and seeking '
                  'stay in step.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KyndrelColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('together-host'),
                  onPressed: _busy ? null : () => unawaited(_run(c.host)),
                  icon: const Icon(Icons.add),
                  label: Text(
                    relay.isEmpty
                        ? 'Start a room on this network'
                        : 'Start a room',
                  ),
                ),
                if (relay.isNotEmpty)
                  TextButton(
                    key: const Key('together-host-lan'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_run(() => c.host(lan: true))),
                    child: const Text('On this network only'),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('together-invite'),
                        controller: _invite,
                        decoration: const InputDecoration(
                          hintText: 'Invite (ABC123…)',
                          isDense: true,
                        ),
                        onSubmitted: (v) => unawaited(_run(() => c.join(v))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('together-join'),
                      onPressed: _busy
                          ? null
                          : () => unawaited(_run(() => c.join(_invite.text))),
                      child: const Text('Join'),
                    ),
                  ],
                ),
                if (relay.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'For friends elsewhere, set up a relay in Settings › '
                      'Watch together.',
                      style: TextStyle(
                        fontSize: 11,
                        color: KyndrelColors.textSecondary,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      key: const Key('together-error'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: KyndrelColors.error,
                      ),
                    ),
                  ),
              ],
            )
          : _Room(session: session, chat: _chat),
    );
  }
}

class _Room extends ConsumerWidget {
  const new({required this.session, required this.chat});

  final TogetherSession session;
  final TextEditingController chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(togetherProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                session.isHost ? 'YOUR ROOM' : 'IN A ROOM',
                style: KyndrelTheme.sectionLabel,
              ),
            ),
            TextButton(
              key: const Key('together-leave'),
              onPressed: () => unawaited(c.leave()),
              child: const Text('Leave'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                session.invite,
                key: const Key('together-code'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy the invite',
              onPressed: () => unawaited(
                Clipboard.setData(ClipboardData(text: session.invite)),
              ),
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ),
        Text(
          [for (final p in session.peers) p.name].join(', '),
          style: const TextStyle(
            fontSize: 12,
            color: KyndrelColors.textSecondary,
          ),
        ),
        if (session.hostTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'The host is playing ${session.hostTitle}.',
              key: const Key('together-other-file'),
              style: const TextStyle(fontSize: 12, color: KyndrelColors.error),
            ),
          ),
        const Divider(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView(
            shrinkWrap: true,
            reverse: true,
            children: [
              for (final m in session.messages.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: m.notice ? '${m.name} ' : '${m.name}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: m.text),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: m.notice
                          ? KyndrelColors.textSecondary
                          : KyndrelColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextField(
          key: const Key('together-chat'),
          controller: chat,
          decoration: const InputDecoration(
            hintText: 'Say something',
            isDense: true,
          ),
          onSubmitted: (v) {
            c.say(v);
            chat.clear();
          },
        ),
      ],
    );
  }
}
