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

    test('backspace safely clamps a stale cursor on an empty line', () {
      final ta = TextAreaModel(value: '', cursorCol: 99);
      expect(ta.update(_special(KeyCode.backspace)).$1, same(ta));
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

    test('dynamic height grows for newlines and soft-wrapped rows', () {
      var ta = TextAreaModel(
        dynamicHeight: true,
        minHeight: 1,
        maxHeight: 4,
        width: 4,
      );
      expect(ta.visibleHeight, 1);

      ta = ta.update(_special(KeyCode.enter)).$1 as TextAreaModel;
      expect(ta.visibleHeight, 2);

      ta = TextAreaModel(
        value: 'abcd',
        cursorCol: 4,
        dynamicHeight: true,
        minHeight: 1,
        maxHeight: 4,
        width: 4,
      );
      ta = ta.update(_char('e')).$1 as TextAreaModel;
      expect(ta.visibleHeight, 2);
      expect(ta.visualLineCount, 2);
    });

    test('dynamic height shrinks after deletion and clamps stale scrolling',
        () {
      final ta = TextAreaModel(
        value: 'abcde',
        cursorCol: 5,
        scrollOffset: 1,
        dynamicHeight: true,
        minHeight: 1,
        maxHeight: 3,
        width: 4,
      );

      final next = ta.update(_special(KeyCode.backspace)).$1 as TextAreaModel;
      expect(next.value, 'abcd');
      expect(next.visibleHeight, 1);
      expect(next.scrollOffset, 0);
    });

    test('dynamic visible height obeys minimum and maximum bounds', () {
      final minimum = TextAreaModel(
        dynamicHeight: true,
        minHeight: 2,
        maxHeight: 0,
      );
      expect(minimum.visibleHeight, 2);
      expect(minimum.view().content.split('\n'), hasLength(2));
      expect(
        TextAreaModel(
          value: 'a\nb\nc\nd',
          dynamicHeight: true,
          minHeight: 2,
          maxHeight: 3,
        ).visibleHeight,
        3,
      );
    });

    test('maxContentHeight rejects edits atomically by visual row count', () {
      final ta = TextAreaModel(
        value: 'abcdef',
        cursorCol: 6,
        width: 3,
        maxHeight: 2,
        maxContentHeight: 2,
      );

      expect(ta.update(_char('g')).$1, same(ta));
      expect(ta.update(_special(KeyCode.enter)).$1, same(ta));
      expect(ta.value, 'abcdef');
    });

    test('multi-grapheme text events are admitted or rejected as one edit', () {
      final allowed = TextAreaModel(
        value: 'ab',
        cursorCol: 2,
        width: 3,
        maxContentHeight: 2,
      ).update(_char('cd')).$1 as TextAreaModel;
      expect((allowed.value, allowed.cursorCol), ('abcd', 4));

      final blocked = allowed.copyWith(maxContentHeight: 2);
      expect(blocked.update(_char('efg')).$1, same(blocked));
      expect(blocked.value, 'abcd');
    });

    test('page keys move by the visible visual page and keep cursor visible',
        () {
      var ta = TextAreaModel(
        value: List.generate(8, (index) => 'line$index').join('\n'),
        cursorRow: 0,
        cursorCol: 2,
        maxHeight: 3,
        width: 20,
      );

      ta = ta.update(_special(KeyCode.pageDown)).$1 as TextAreaModel;
      expect((ta.cursorRow, ta.cursorCol), (3, 2));
      expect(ta.cursorVisualRow, 3);
      expect(ta.scrollOffset, 1);

      ta = ta.update(_special(KeyCode.pageUp)).$1 as TextAreaModel;
      expect((ta.cursorRow, ta.cursorCol), (0, 2));
      expect(ta.scrollOffset, 0);
    });

    test('page keys traverse wrapped rows within one logical line', () {
      var ta = TextAreaModel(
        value: 'abcdefghi',
        cursorCol: 1,
        maxHeight: 2,
        width: 3,
      );

      ta = ta.update(_special(KeyCode.pageDown)).$1 as TextAreaModel;
      expect((ta.cursorRow, ta.cursorCol), (0, 7));
      expect((ta.cursorVisualRow, ta.scrollOffset), (2, 1));

      ta = ta.update(_special(KeyCode.pageUp)).$1 as TextAreaModel;
      expect((ta.cursorRow, ta.cursorCol), (0, 1));
      expect((ta.cursorVisualRow, ta.scrollOffset), (0, 0));
    });

    test('cursor and vertical movement use soft-wrapped visual rows', () {
      var ta = TextAreaModel(
        value: 'abcdef',
        cursorCol: 1,
        maxHeight: 2,
        width: 3,
      );

      ta = ta.update(_special(KeyCode.down)).$1 as TextAreaModel;
      expect((ta.cursorRow, ta.cursorCol), (0, 4));
      expect(ta.cursorVisualRow, 1);
      final cursor = ta.view().cursor!;
      expect((cursor.x, cursor.y, cursor.shape), (1, 1, CursorShape.bar));
      expect(ta.scrollPercent, 1.0);
    });
  });
}
