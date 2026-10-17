import 'dart:convert';

import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/key_buffer_parser.dart';
import 'package:dart_tui/src/msg.dart';
import 'package:test/test.dart';

void main() {
  test('parseKeyFromBuffer handles printable ASCII', () {
    final b = <int>[0x61];
    final k = parseKeyFromBuffer(b);
    expect(k?.code, KeyCode.rune);
    expect(k?.text, 'a');
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer consumes one scalar per key', () {
    final input = [0x61, 0x62, 0xc3, 0xa9, 0x63];
    final keys = <String?>[];
    while (input.isNotEmpty) {
      keys.add(parseKeyFromBuffer(input)?.text);
    }
    expect(keys, ['a', 'b', 'é', 'c']);
  });

  test('streaming decoder emits one key event per scalar', () {
    final messages = TerminalInputDecoder().feed(utf8.encode('abéc'));
    expect(
      messages.whereType<KeyPressMsg>().map((message) => message.key),
      ['a', 'b', 'é', 'c'],
    );
  });

  test('parseKeyFromBuffer decodes UTF-8 scalar values', () {
    for (final text in ['é', '你', '🧑']) {
      expect(parseKeyFromBuffer(utf8.encode(text).toList())?.text, text);
    }
  });

  test('parseKeyFromBuffer waits for fragmented UTF-8', () {
    final input = [0xc3];
    expect(parseKeyFromBuffer(input), isNull);
    expect(input, [0xc3]);
    input.add(0xa9);
    expect(parseKeyFromBuffer(input)?.text, 'é');
  });

  test('parseKeyFromBuffer consumes malformed UTF-8 one byte at a time', () {
    final invalidLead = [0xff, 0x61];
    expect(parseKeyFromBuffer(invalidLead)?.code, KeyCode.unknown);
    expect(invalidLead, [0x61]);
    expect(parseKeyFromBuffer(invalidLead)?.text, 'a');

    final invalidContinuation = [0xe2, 0x28, 0xa1];
    expect(parseKeyFromBuffer(invalidContinuation)?.code, KeyCode.unknown);
    expect(invalidContinuation, [0x28, 0xa1]);
    expect(parseKeyFromBuffer(invalidContinuation)?.text, '(');
  });

  test('parseKeyFromBuffer parses arrow escape sequence', () {
    final b = <int>[0x1b, 0x5b, 0x42];
    final k = parseKeyFromBuffer(b);
    expect(k?.code, KeyCode.down);
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer parses CSI Z (backtab) as shift+tab', () {
    final b = <int>[0x1b, 0x5b, 0x5a];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.tab);
    expect(k.modifiers, contains(KeyMod.shift));
    expect(k.keystroke(), 'shift+tab');
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer returns null until escape sequence complete', () {
    final b = <int>[0x1b];
    expect(parseKeyFromBuffer(b), isNull);
    expect(b, [0x1b]);
    b.addAll([0x5b, 0x41]);
    final k = parseKeyFromBuffer(b);
    expect(k?.code, KeyCode.up);
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer parses right arrow', () {
    final b = <int>[0x1b, 0x5b, 0x43];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.right);
  });

  test('parseKeyFromBuffer parses ctrl+a', () {
    final b = <int>[0x01];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.rune);
    expect(k.text, 'a');
    expect(k.modifiers, {KeyMod.ctrl});
  });

  test('parseKeyFromBuffer parses backspace', () {
    final b = <int>[0x7f];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.backspace);
  });

  test('parseKeyFromBuffer parses enter (CR)', () {
    final b = <int>[0x0d];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.enter);
  });

  test('parseKeyFromBuffer parses enter (LF, Linux/WSL terminals)', () {
    final b = <int>[0x0a];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.enter);
  });

  test('parseKeyFromBuffer parses tab', () {
    final b = <int>[0x09];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.tab);
  });

  test('parseKeyFromBuffer parses delete', () {
    final b = <int>[0x1b, 0x5b, 0x33, 0x7e];
    final k = parseKeyFromBuffer(b)!;
    expect(k.code, KeyCode.delete);
  });

  test('parseKeyFromBuffer maps ESC-prefixed runes to alt keys', () {
    // Option-as-Meta / Esc+ terminals send Alt+key as ESC followed by the key.
    final input = [0x1b, 0x61, 0x1b, 0x58, 0x1b, ...utf8.encode('é')];
    final keys = <String>[];
    while (input.isNotEmpty) {
      keys.add(KeyPressMsg(parseKeyFromBuffer(input)!).key);
    }
    expect(keys, ['alt+a', 'alt+X', 'alt+é']);
  });

  test('parseKeyFromBuffer waits for a fragmented alt scalar', () {
    final input = [0x1b, 0xc3];
    expect(parseKeyFromBuffer(input), isNull);
    input.add(0xa9);
    expect(KeyPressMsg(parseKeyFromBuffer(input)!).key, 'alt+é');
  });

  test('parseKeyFromBuffer keeps legacy alt word-motion sequences', () {
    for (final (bytes, key) in [
      ([0x1b, 0x62], 'alt+left'),
      ([0x1b, 0x66], 'alt+right'),
      ([0x1b, 0x7f], 'alt+backspace'),
    ]) {
      expect(KeyPressMsg(parseKeyFromBuffer(bytes)!).key, key);
    }
  });
}
