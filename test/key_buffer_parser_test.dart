import 'package:dart_console/dart_console.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/key_buffer_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parseKeyFromBuffer handles printable and ctrl', () {
    final b = <int>[0x61];
    final k = parseKeyFromBuffer(b);
    expect(k?.isControl, false);
    expect(k?.char, 'a');
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer parses arrow escape sequence', () {
    final b = <int>[0x1b, 0x5b, 0x42];
    final k = parseKeyFromBuffer(b);
    expect(k?.isControl, true);
    expect(k?.controlChar, ControlCharacter.arrowDown);
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer returns null until escape sequence complete', () {
    final b = <int>[0x1b];
    expect(parseKeyFromBuffer(b), isNull);
    expect(b, [0x1b]);
    b.addAll([0x5b, 0x41]);
    final k = parseKeyFromBuffer(b);
    expect(k?.controlChar, ControlCharacter.arrowUp);
    expect(b, isEmpty);
  });

  test('parseKeyFromBuffer maps to same tea strings as readKey would', () {
    final b = <int>[0x1b, 0x5b, 0x43];
    final k = parseKeyFromBuffer(b)!;
    expect(keyToTeaString(k), 'right');
  });
}
