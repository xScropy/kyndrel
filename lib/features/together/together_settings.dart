import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/net/cloudflare_relay.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Settings › Watch together (task 9.11): the name others see, and the
/// relay for rooms with friends elsewhere, which Kyndrel can put on the
/// user's own free Cloudflare account (as Harbor does).
class TogetherSettings extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TogetherSettings> createState() => _TogetherSettingsState();
}

class _TogetherSettingsState extends ConsumerState<TogetherSettings> {
  final _token = TextEditingController();
  bool _deploying = false;
  String? _message;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _deploy() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    setState(() {
      _deploying = true;
      _message = null;
    });
    final cf = CloudflareRelay(token: token);
    try {
      final script = await rootBundle.loadString('assets/together/worker.js');
      final url = await cf.deploy(script);
      updateSettings(ref, (s) => s.copyWith(togetherRelay: '$url'));
      _token.clear();
      _message = 'Your relay is ready: $url';
    } on CloudflareException catch (e) {
      _message = "Couldn't set it up: ${e.message}";
    } on Object catch (e) {
      _message = "Couldn't reach Cloudflare: $e";
    } finally {
      cf.close();
    }
    if (mounted) setState(() => _deploying = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Watch together',
      children: [
        const Text(
          'Start a room from the player (the people button) and send the '
          'invite. On the same Wi-Fi it works as it is; for friends '
          'elsewhere, rooms go through a relay.',
          style: TextStyle(fontSize: 12, color: KyndrelColors.textSecondary),
        ),
        const SizedBox(height: 12),
        SettingsTextField(
          key: const Key('settings-together-name'),
          label: 'Your name',
          helper: 'What the others see',
          value: s.togetherName,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(togetherName: v.trim())),
        ),
        SettingsTextField(
          key: const Key('settings-together-relay'),
          label: 'Relay address',
          helper: "wss://… — yours, or a friend's. Empty: this network only",
          value: s.togetherRelay,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(togetherRelay: v.trim())),
        ),
        const SizedBox(height: 8),
        const Text(
          'SET UP YOUR OWN RELAY (FREE)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KyndrelColors.sectionLabel,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Make a Cloudflare account, then an API token with "Edit '
          'Cloudflare Workers" (My Profile › API Tokens). Kyndrel puts the '
          'relay on your account; the token is not kept.',
          style: TextStyle(fontSize: 12, color: KyndrelColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('settings-together-token'),
                controller: _token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Cloudflare API token',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('settings-together-deploy'),
              onPressed: _deploying ? null : () => unawaited(_deploy()),
              child: _deploying
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Set up'),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              _message!,
              key: const Key('settings-together-message'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
