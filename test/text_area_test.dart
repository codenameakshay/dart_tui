import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

/// Helper: create a [KeyPressMsg] for a special key by [KeyCode].
KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));

void main() {
  group('TextAreaModel', () {
    test('inserts character at cursor', () {
      final ta = TextAreaModel();
      final (next, _) = ta.update(_char('a'));
      expect((next as TextAreaModel).value, 'a');
    });

    test('inserts newline on enter', () {
      final ta = TextAreaModel(value: 'ab', cursorRow: 0, cursorCol: 2);
      final (next, _) = ta.update(_special(KeyCode.enter));
      expect((next as TextAreaModel).value, 'ab\n');
      expect(next.cursorRow, 1);
    });

    test('backspace removes preceding character', () {
      final ta = TextAreaModel(value: 'abc', cursorRow: 0, cursorCol: 3);
      final (next, _) = ta.update(_special(KeyCode.backspace));
      expect((next as TextAreaModel).value, 'ab');
    });

    test('charLimit blocks input', () {
      final ta =
          TextAreaModel(value: 'ab', charLimit: 2, cursorRow: 0, cursorCol: 2);
      final (next, _) = ta.update(_char('c'));
      expect((next as TextAreaModel).value, 'ab');
    });

    test('navigates down to next line', () {
      final ta = TextAreaModel(value: 'abc\ndef', cursorRow: 0, cursorCol: 1);
      final (next, _) = ta.update(_special(KeyCode.down));
      expect((next as TextAreaModel).cursorRow, 1);
    });
  });
}
