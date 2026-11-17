/// Parses `mpv.conf`-style lines (`name=value`, `# comments`) for the
/// advanced settings passthrough (task 5.1).
({Map<String, String> options, List<String> errors}) parseMpvOptions(
  String text,
) {
  final options = <String, String>{};
  final errors = <String>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash).trim();
    if (line.isEmpty) continue;
    final eq = line.indexOf('=');
    final name = (eq < 0 ? line : line.substring(0, eq)).trim();
    final value = eq < 0 ? 'yes' : line.substring(eq + 1).trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9\-/]*$').hasMatch(name)) {
      errors.add('Line ${i + 1}: "$name" is not an option name.');
      continue;
    }
    // Options that would break Kyndrel's own rendering or control.
    if (const {
      'vo',
      'wid',
      'input-ipc-server',
      'idle',
      'config',
    }.contains(name)) {
      errors.add('Line ${i + 1}: "$name" is managed by Kyndrel.');
      continue;
    }
    options[name] = value.replaceAll(RegExp(r'^"|"$'), '');
  }
  return (options: options, errors: errors);
}
