import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Idle / error screen prompt: open a file, paste a path or URL, or drop a
/// file (task 1.11).
class OpenSourcePrompt extends StatefulWidget {
  const new({required this.onOpen, this.onPickFile, super.key});

  final Future<void> Function(String source) onOpen;
  final VoidCallback? onPickFile;

  @override
  State<OpenSourcePrompt> createState() => _OpenSourcePromptState();
}

class _OpenSourcePromptState extends State<OpenSourcePrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await widget.onOpen(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(20),
      decoration: KyndrelTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('OPEN MEDIA', style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 12),
          if (widget.onPickFile != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('open-file'),
                onPressed: widget.onPickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open file…  (Ctrl+O)'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('open-source-field'),
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Paste a path or URL',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _submit, child: const Text('Open')),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Or drop a file anywhere in the window. Ctrl+N opens streams, '
            'shares and WebDAV folders.',
            style: TextStyle(color: KyndrelColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
