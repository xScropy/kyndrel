import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A key with modifiers, e.g. Ctrl+Shift+S.
@immutable
class KeyCombo {
  const new(
    this.key, {
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  });

  /// From the current keyboard state. Cmd counts as Ctrl on macOS.
  factory fromEvent(KeyEvent event) {
    final k = HardwareKeyboard.instance;
    return KeyCombo(
      event.logicalKey,
      ctrl: k.isControlPressed || k.isMetaPressed,
      shift: k.isShiftPressed,
      alt: k.isAltPressed,
    );
  }

  /// Parses [serialize]'s output; null if malformed.
  static KeyCombo? parse(String s) {
    final parts = s.split('+');
    final id = int.tryParse(parts.last, radix: 16);
    if (id == null) return null;
    final key = LogicalKeyboardKey.findKeyByKeyId(id) ?? LogicalKeyboardKey(id);
    return KeyCombo(
      key,
      ctrl: parts.contains('ctrl'),
      shift: parts.contains('shift'),
      alt: parts.contains('alt'),
    );
  }

  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool shift;
  final bool alt;

  String serialize() => [
    if (ctrl) 'ctrl',
    if (shift) 'shift',
    if (alt) 'alt',
    key.keyId.toRadixString(16),
  ].join('+');

  /// `Ctrl+Shift+S`, `Space`, `←`.
  String get label {
    final name = switch (key) {
      LogicalKeyboardKey.space => 'Space',
      LogicalKeyboardKey.arrowLeft => '←',
      LogicalKeyboardKey.arrowRight => '→',
      LogicalKeyboardKey.arrowUp => '↑',
      LogicalKeyboardKey.arrowDown => '↓',
      LogicalKeyboardKey.escape => 'Esc',
      LogicalKeyboardKey.pageUp => 'PgUp',
      LogicalKeyboardKey.pageDown => 'PgDn',
      _ =>
        key.keyLabel.isEmpty
            ? key.debugName ?? '?'
            : key.keyLabel.toUpperCase(),
    };
    return [
      if (ctrl) 'Ctrl',
      if (shift) 'Shift',
      if (alt) 'Alt',
      name,
    ].join('+');
  }

  /// Modifier keys pressed alone are never a binding.
  bool get isModifierOnly => {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  }.contains(key);

  @override
  bool operator ==(Object other) =>
      other is KeyCombo &&
      other.key == key &&
      other.ctrl == ctrl &&
      other.shift == shift &&
      other.alt == alt;

  @override
  int get hashCode => Object.hash(key, ctrl, shift, alt);

  @override
  String toString() => label;
}

/// Everything a shortcut can do (task 1.9, rebinding 5.1).
enum PlayerAction {
  playPause('Play / pause', KeyCombo(LogicalKeyboardKey.space)),
  seekBack('Seek back', KeyCombo(LogicalKeyboardKey.arrowLeft), repeats: true),
  seekForward(
    'Seek forward',
    KeyCombo(LogicalKeyboardKey.arrowRight),
    repeats: true,
  ),
  volumeUp('Volume up', KeyCombo(LogicalKeyboardKey.arrowUp), repeats: true),
  volumeDown(
    'Volume down',
    KeyCombo(LogicalKeyboardKey.arrowDown),
    repeats: true,
  ),
  mute('Mute', KeyCombo(LogicalKeyboardKey.keyM)),
  fullscreen('Full screen', KeyCombo(LogicalKeyboardKey.keyF)),
  back('Close panel / leave full screen', KeyCombo(LogicalKeyboardKey.escape)),
  slower('Slower', KeyCombo(LogicalKeyboardKey.bracketLeft), repeats: true),
  faster('Faster', KeyCombo(LogicalKeyboardKey.bracketRight), repeats: true),
  subtitles('Subtitles & audio panel', KeyCombo(LogicalKeyboardKey.keyS)),
  next('Next in queue', KeyCombo(LogicalKeyboardKey.keyN)),
  previous('Previous in queue', KeyCombo(LogicalKeyboardKey.keyP)),
  queue('Queue', KeyCombo(LogicalKeyboardKey.keyQ)),
  nextChapter('Next chapter', KeyCombo(LogicalKeyboardKey.pageDown)),
  previousChapter('Previous chapter', KeyCombo(LogicalKeyboardKey.pageUp)),
  abLoop('A-B loop', KeyCombo(LogicalKeyboardKey.keyL)),
  nextFrame('Next frame', KeyCombo(LogicalKeyboardKey.period), repeats: true),
  previousFrame(
    'Previous frame',
    KeyCombo(LogicalKeyboardKey.comma),
    repeats: true,
  ),
  pip('Picture in picture', KeyCombo(LogicalKeyboardKey.keyI)),
  openFile('Open file', KeyCombo(LogicalKeyboardKey.keyO, ctrl: true)),
  paste(
    'Open pasted path or URL',
    KeyCombo(LogicalKeyboardKey.keyV, ctrl: true),
  ),
  openUrl('Open network stream', KeyCombo(LogicalKeyboardKey.keyN, ctrl: true)),
  effects(
    'Video & audio effects',
    KeyCombo(LogicalKeyboardKey.keyE, ctrl: true),
  ),
  mediaInfo('Media info', KeyCombo(LogicalKeyboardKey.keyI, ctrl: true)),
  screenshot('Screenshot', KeyCombo(LogicalKeyboardKey.keyS, ctrl: true)),
  settings('Settings', KeyCombo(LogicalKeyboardKey.comma, ctrl: true)),
  // Task 8.8.
  bookmark('Add a bookmark here', KeyCombo(LogicalKeyboardKey.keyB)),
  bookmarks('Bookmarks', KeyCombo(LogicalKeyboardKey.keyB, ctrl: true)),
  jumpToTime('Jump to time', KeyCombo(LogicalKeyboardKey.keyG, ctrl: true)),
  decoder('Hardware / software decoding', KeyCombo(LogicalKeyboardKey.keyH)),
  stats('Playback statistics', KeyCombo(LogicalKeyboardKey.keyI, shift: true));

  new(this.label, this.defaultCombo, {this.repeats = false});

  final String label;
  final KeyCombo defaultCombo;

  /// Holding the key repeats the action.
  final bool repeats;
}

/// The active bindings: defaults with the user's overrides. An override
/// of `''` unbinds the action.
@immutable
class KeyBindings {
  const new([this.overrides = const {}]);

  /// Action name → serialized combo (or '' for none).
  final Map<String, String> overrides;

  KeyCombo? comboFor(PlayerAction a) {
    final o = overrides[a.name];
    if (o == null) return a.defaultCombo;
    if (o.isEmpty) return null;
    return KeyCombo.parse(o);
  }

  /// Which action [combo] triggers, if any.
  PlayerAction? actionFor(KeyCombo combo) {
    for (final a in PlayerAction.values) {
      if (comboFor(a) == combo) return a;
    }
    return null;
  }

  /// Binds [combo] to [action]; any other action using it is unbound.
  KeyBindings bind(PlayerAction action, KeyCombo combo) {
    final next = {...overrides};
    for (final other in PlayerAction.values) {
      if (other != action && comboFor(other) == combo) next[other.name] = '';
    }
    next[action.name] = combo == action.defaultCombo ? '' : combo.serialize();
    if (combo == action.defaultCombo) next.remove(action.name);
    return KeyBindings(next);
  }

  KeyBindings unbind(PlayerAction action) =>
      KeyBindings({...overrides, action.name: ''});

  KeyBindings reset(PlayerAction action) =>
      KeyBindings({...overrides}..remove(action.name));

  @override
  bool operator ==(Object other) =>
      other is KeyBindings && mapEquals(other.overrides, overrides);

  @override
  int get hashCode =>
      Object.hashAll(overrides.entries.map((e) => e.toString()));
}
