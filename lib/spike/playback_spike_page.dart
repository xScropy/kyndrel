// Phase 0 spike (task 0.5). Throwaway: delete once task 1.1 lands.
//
// This is the only file outside core/player allowed to touch media_kit
// directly, and only because PlayerService does not exist yet.

import 'dart:async';

import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlaybackSpikePage extends StatefulWidget {
  const new({this.initialSource, super.key});

  final String? initialSource;

  @override
  State<PlaybackSpikePage> createState() => _PlaybackSpikePageState();
}

class _PlaybackSpikePageState extends State<PlaybackSpikePage> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      // 'auto-safe' lets mpv pick a hardware decoder and fall back to
      // software if none works.
      hwdec: 'auto-safe',
    ),
  );
  final TextEditingController _source = TextEditingController();
  Timer? _diagnosticsTimer;
  Map<String, String> _diagnostics = const {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSource;
    if (initial != null) {
      _source.text = initial;
      unawaited(_open(initial));
    }
    _diagnosticsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshDiagnostics()),
    );
  }

  Future<void> _open(String source) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return;
    await _player.open(Media(trimmed));
  }

  /// Reads the mpv properties that prove whether hardware decoding is active.
  Future<void> _refreshDiagnostics() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    const props = [
      'hwdec-current',
      'video-codec',
      'width',
      'height',
      'container-fps',
      'estimated-vf-fps',
      'frame-drop-count',
    ];
    final values = <String, String>{};
    for (final p in props) {
      try {
        values[p] = await platform.getProperty(p);
      } on Object {
        values[p] = '—';
      }
    }
    if (mounted) setState(() => _diagnostics = values);
  }

  @override
  void dispose() {
    _diagnosticsTimer?.cancel();
    _source.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _source,
                    decoration: const InputDecoration(
                      hintText: 'File path or URL',
                      isDense: true,
                    ),
                    onSubmitted: _open,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _open(_source.text),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Video(controller: _controller),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _DiagnosticsPanel(values: _diagnostics),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const new({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final hwdec = values['hwdec-current'] ?? '';
    final hardware = hwdec.isNotEmpty && hwdec != 'no' && hwdec != '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: KyndrelTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DIAGNOSTICS', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 8),
          Text(
            hardware ? 'Hardware decoding: $hwdec' : 'Software decoding',
            style: TextStyle(
              color: hardware ? KyndrelColors.accent : KyndrelColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final e in values.entries)
            Text(
              '${e.key}: ${e.value}',
              style: const TextStyle(
                color: KyndrelColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
