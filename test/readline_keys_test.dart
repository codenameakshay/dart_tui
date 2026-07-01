import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _ctrl(String t) => KeyPressMsg(
    TeaKey(code: KeyCode.rune, text: t, modifiers: const {KeyMod.ctrl}));
KeyPressMsg _altBackspace() =>
    KeyPressMsg(const TeaKey(code: KeyCode.backspace, modifiers: {KeyMod.alt}));
KeyPressMsg _altLeft() =>
    KeyPressMsg(const TeaKey(code: KeyCode.left, modifiers: {KeyMod.alt}));
KeyPressMsg _altRight() =>
    KeyPressMsg(const TeaKey(code: KeyCode.right, modifiers: {KeyMod.alt}));

void main() {
  group('TextInputModel readline keys', () {
    test('ctrl+a home, ctrl+e end', () {
      final m = TextInputModel(value: 'hello world', cursorPos: 5);
      expect((m.update(_ctrl('a')).$1 as TextInputModel).cursorPos, 0);
      expect((m.update(_ctrl('e')).$1 as TextInputModel).cursorPos, 11);
    });

    test('ctrl+b / ctrl+f move by character', () {
      final m = TextInputModel(value: 'ab', cursorPos: 1);
      expect((m.update(_ctrl('b')).$1 as TextInputModel).cursorPos, 0);
      expect((m.update(_ctrl('f')).$1 as TextInputModel).cursorPos, 2);
    });

    test('alt+left / alt+right move by word', () {
      final wl = TextInputModel(value: 'foo bar baz', cursorPos: 11)
          .update(_altLeft())
          .$1 as TextInputModel;
      expect(wl.cursorPos, 8); // start of 'baz'
      final wr = TextInputModel(value: 'foo bar', cursorPos: 0)
          .update(_altRight())
          .$1 as TextInputModel;
      expect(wr.cursorPos, 3); // end of 'foo'
    });

    test('ctrl+w / alt+backspace delete the previous word', () {
      final m = TextInputModel(value: 'foo bar', cursorPos: 7);
      expect((m.update(_ctrl('w')).$1 as TextInputModel).value, 'foo ');
      expect((m.update(_altBackspace()).$1 as TextInputModel).value, 'foo ');
      // at column 0 it is a no-op
      final start = TextInputModel(value: 'x', cursorPos: 0);
      expect(start.update(_ctrl('w')).$1, same(start));
    });
  });

  group('TextAreaModel readline keys', () {
    test('ctrl+a / ctrl+e jump within the current line', () {
      final m = TextAreaModel(value: 'ab\nhello', cursorRow: 1, cursorCol: 3);
      expect((m.update(_ctrl('a')).$1 as TextAreaModel).cursorCol, 0);
      expect((m.update(_ctrl('e')).$1 as TextAreaModel).cursorCol, 5);
    });

    test('ctrl+w deletes the previous word in the current line', () {
      final m = TextAreaModel(value: 'foo bar', cursorRow: 0, cursorCol: 7);
      expect((m.update(_ctrl('w')).$1 as TextAreaModel).value, 'foo ');
    });
  });
}
