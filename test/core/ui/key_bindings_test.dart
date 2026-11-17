import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/player/mpv_options.dart';
import 'package:kyndrel/core/ui/key_bindings.dart';

void main() {
  test('combos serialize, parse and label', () {
    const c = KeyCombo(LogicalKeyboardKey.keyS, ctrl: true, shift: true);
    expect(KeyCombo.parse(c.serialize()), c);
    expect(c.label, 'Ctrl+Shift+S');
    expect(const KeyCombo(LogicalKeyboardKey.space).label, 'Space');
    expect(KeyCombo.parse('nonsense'), isNull);
  });

  test('defaults cover every action and do not collide', () {
    const b = KeyBindings();
    final combos = PlayerAction.values.map(b.comboFor).toList();
    expect(combos.toSet(), hasLength(PlayerAction.values.length));
    expect(
      b.actionFor(const KeyCombo(LogicalKeyboardKey.keyM)),
      PlayerAction.mute,
    );
  });

  test('binding a used key moves it; reset and unbind', () {
    const k = KeyCombo(LogicalKeyboardKey.keyK);
    var b = const KeyBindings().bind(PlayerAction.mute, k);
    expect(b.actionFor(k), PlayerAction.mute);
    expect(b.actionFor(const KeyCombo(LogicalKeyboardKey.keyM)), isNull);

    // F is fullscreen's; giving it to mute unbinds fullscreen.
    b = b.bind(PlayerAction.mute, const KeyCombo(LogicalKeyboardKey.keyF));
    expect(b.comboFor(PlayerAction.fullscreen), isNull);
    b = b.reset(PlayerAction.fullscreen).reset(PlayerAction.mute);
    expect(b.comboFor(PlayerAction.fullscreen)!.label, 'F');
    expect(b.comboFor(PlayerAction.mute)!.label, 'M');
    expect(b.unbind(PlayerAction.mute).comboFor(PlayerAction.mute), isNull);
  });

  test('mpv option passthrough parsing', () {
    final r = parseMpvOptions('''
# comment
cache-secs=60
sub-font = "Noto Sans"   # trailing comment
deband
vo=gpu
Bad Name=1
''');
    expect(r.options, {
      'cache-secs': '60',
      'sub-font': 'Noto Sans',
      'deband': 'yes',
    });
    expect(r.errors, hasLength(2));
    expect(r.errors.first, contains('managed by Kyndrel'));
  });
}
