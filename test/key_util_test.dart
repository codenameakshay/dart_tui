import 'package:dart_console/dart_console.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('keyToTeaString maps arrows', () {
    expect(keyToTeaString(Key.control(ControlCharacter.arrowUp)), 'up');
    expect(keyToTeaString(Key.control(ControlCharacter.enter)), 'enter');
    expect(keyToTeaString(Key.printable('a')), 'a');
  });
}
