import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/l10n/l10n.dart';
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
          Text(context.l10n.openMediaHeader, style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 12),
          if (widget.onPickFile != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('open-file'),
                onPressed: widget.onPickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(context.l10n.openFileShortcut),
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
                  decoration: InputDecoration(
                    hintText: context.l10n.pastePathOrUrl,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _submit,
                child: Text(context.l10n.open),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.dropHint,
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
