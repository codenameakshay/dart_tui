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

  test('parseKeyFromBuffer parses arrow escape sequence', () {
    final b = <int>[0x1b, 0x5b, 0x42];
    final k = parseKeyFromBuffer(b);
    expect(k?.code, KeyCode.down);
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
}
