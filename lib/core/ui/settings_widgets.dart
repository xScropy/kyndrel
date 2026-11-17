import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Updates and saves settings from a settings widget.
void updateSettings(WidgetRef ref, AppSettings Function(AppSettings) f) =>
    ref.read(settingsProvider.notifier).update(f).ignore();

/// A titled group on the settings page.
class SettingsSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: KyndrelTheme.sectionLabel),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

/// A text field bound to one setting; saves as you type.
class SettingsTextField extends StatefulWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.secret = false,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final String value;
  final String? helper;
  final bool secret;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final _c = TextEditingController(text: widget.value);
  bool _show = false;

  @override
  void didUpdateWidget(SettingsTextField old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: _c,
      obscureText: widget.secret && !_show,
      maxLines: widget.secret ? 1 : widget.maxLines,
      style: widget.maxLines > 1
          ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        alignLabelWithHint: widget.maxLines > 1,
        suffixIcon: widget.secret
            ? IconButton(
                tooltip: _show ? 'Hide' : 'Show',
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              )
            : null,
      ),
      onChanged: widget.onChanged,
    ),
  );
}
