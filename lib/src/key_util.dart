import 'package:dart_console/dart_console.dart' as dc;

import 'msg.dart';

/// Maps [dart_console] [Key] to Bubble Tea-style [TeaKey].
TeaKey toTeaKey(dc.Key key) {
  if (!key.isControl) {
    return TeaKey(code: KeyCode.rune, text: key.char);
  }
  if (!key.isControl) {
    return TeaKey(code: KeyCode.rune, text: key.char);
  }
  return switch (key.controlChar) {
    dc.ControlCharacter.arrowUp => const TeaKey(code: KeyCode.up),
    dc.ControlCharacter.arrowDown => const TeaKey(code: KeyCode.down),
    dc.ControlCharacter.arrowLeft => const TeaKey(code: KeyCode.left),
    dc.ControlCharacter.arrowRight => const TeaKey(code: KeyCode.right),
    dc.ControlCharacter.enter => const TeaKey(code: KeyCode.enter),
    dc.ControlCharacter.tab => const TeaKey(code: KeyCode.tab),
    dc.ControlCharacter.escape => const TeaKey(code: KeyCode.escape),
    dc.ControlCharacter.backspace ||
    dc.ControlCharacter.wordBackspace =>
      const TeaKey(code: KeyCode.backspace),
    dc.ControlCharacter.delete => const TeaKey(code: KeyCode.delete),
    dc.ControlCharacter.home => const TeaKey(code: KeyCode.home),
    dc.ControlCharacter.end => const TeaKey(code: KeyCode.end),
    dc.ControlCharacter.pageUp => const TeaKey(code: KeyCode.pageUp),
    dc.ControlCharacter.pageDown => const TeaKey(code: KeyCode.pageDown),
    dc.ControlCharacter.ctrlA => const TeaKey(
        code: KeyCode.rune,
        text: 'a',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlB => const TeaKey(
        code: KeyCode.rune,
        text: 'b',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlC => const TeaKey(
        code: KeyCode.rune,
        text: 'c',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlD => const TeaKey(
        code: KeyCode.rune,
        text: 'd',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlE => const TeaKey(
        code: KeyCode.rune,
        text: 'e',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlF => const TeaKey(
        code: KeyCode.rune,
        text: 'f',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlG => const TeaKey(
        code: KeyCode.rune,
        text: 'g',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlH => const TeaKey(
        code: KeyCode.rune,
        text: 'h',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlJ => const TeaKey(
        code: KeyCode.rune,
        text: 'j',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlK => const TeaKey(
        code: KeyCode.rune,
        text: 'k',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlL => const TeaKey(
        code: KeyCode.rune,
        text: 'l',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlN => const TeaKey(
        code: KeyCode.rune,
        text: 'n',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlO => const TeaKey(
        code: KeyCode.rune,
        text: 'o',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlP => const TeaKey(
        code: KeyCode.rune,
        text: 'p',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlQ => const TeaKey(
        code: KeyCode.rune,
        text: 'q',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlR => const TeaKey(
        code: KeyCode.rune,
        text: 'r',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlS => const TeaKey(
        code: KeyCode.rune,
        text: 's',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlT => const TeaKey(
        code: KeyCode.rune,
        text: 't',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlU => const TeaKey(
        code: KeyCode.rune,
        text: 'u',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlV => const TeaKey(
        code: KeyCode.rune,
        text: 'v',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlW => const TeaKey(
        code: KeyCode.rune,
        text: 'w',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlX => const TeaKey(
        code: KeyCode.rune,
        text: 'x',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlY => const TeaKey(
        code: KeyCode.rune,
        text: 'y',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.ctrlZ => const TeaKey(
        code: KeyCode.rune,
        text: 'z',
        modifiers: {KeyMod.ctrl},
      ),
    dc.ControlCharacter.F1 => const TeaKey(code: KeyCode.f1),
    dc.ControlCharacter.F2 => const TeaKey(code: KeyCode.f2),
    dc.ControlCharacter.F3 => const TeaKey(code: KeyCode.f3),
    dc.ControlCharacter.F4 => const TeaKey(code: KeyCode.f4),
    _ => const TeaKey(code: KeyCode.unknown),
  };
}

/// Legacy helper preserved for older users/examples.
String keyToTeaString(dc.Key key) => toTeaKey(key).keystroke();
