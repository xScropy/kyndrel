import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Minimal "paste a path or URL" field. Task 1.11 adds the file picker,
/// drag-and-drop and file associations.
class OpenSourcePrompt extends StatefulWidget {
  const new({required this.onOpen, super.key});

  final Future<void> Function(String source) onOpen;

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
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('open-source-field'),
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'File path or URL',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _submit, child: const Text('Open')),
            ],
          ),
        ],
      ),
    );
  }
}
