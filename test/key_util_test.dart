import 'package:dart_console/dart_console.dart' as dc;
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('keyToTeaString maps arrows', () {
    expect(keyToTeaString(dc.Key.control(dc.ControlCharacter.arrowUp)), 'up');
    expect(keyToTeaString(dc.Key.control(dc.ControlCharacter.enter)), 'enter');
    expect(keyToTeaString(dc.Key.printable('a')), 'a');
  });
}
