import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

/// Helper: create a [KeyPressMsg] for a special key by [KeyCode].
KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));

void main() {
  group('TextAreaModel', () {
    test('exposes grapheme cursor and visible viewport state', () {
      final ta = TextAreaModel(
        value: 'first\n👨‍👩‍👧‍👦é\nthird\nfourth',
        cursorRow: 1,
        cursorCol: 1,
        scrollOffset: 99,
        maxHeight: 2,
      );

      expect((ta.cursorLine, ta.cursorColumn), (1, 1));
      expect(ta.visibleScrollOffset, 2);
      expect(ta.visibleHeight, 2);
    });

    test('moves immutably to line and document boundaries', () {
      final ta = TextAreaModel(
        value: 'first\n👨‍👩‍👧‍👦é\nlast',
        cursorRow: 1,
        cursorCol: 1,
        maxHeight: 2,
      );

      expect(ta.moveToLineStart().cursorColumn, 0);
      expect(ta.moveToLineEnd().cursorColumn, 2);
      expect(
        (
          ta.moveToDocumentStart().cursorLine,
          ta.moveToDocumentStart().cursorColumn
        ),
        (0, 0),
      );
      expect(
        (
          ta.moveToDocumentEnd().cursorLine,
          ta.moveToDocumentEnd().cursorColumn
        ),
        (2, 4),
      );
      expect((ta.cursorLine, ta.cursorColumn), (1, 1));
    });

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

  group('TextAreaModel multi-scalar graphemes', () {
    const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';

    // The parser delivers one KeyPressMsg per Unicode scalar.
    TextAreaModel typeScalars(TextAreaModel ta, String text) {
      for (final rune in text.runes) {
        ta = ta.update(_char(String.fromCharCode(rune))).$1 as TextAreaModel;
      }
      return ta;
    }

    for (final (name, cluster) in const [
      ('family', family),
      ('skin tone', '\u{1F44D}\u{1F3FD}'),
      ('flag', '\u{1F1EE}\u{1F1F3}'),
      ('variation selector', '\u2764\uFE0F'),
    ]) {
      test('$name typed before existing text lands after the cluster', () {
        var ta = typeScalars(TextAreaModel(value: 'Z'), cluster);
        expect(ta.value, '${cluster}Z');
        expect(ta.cursorColumn, 1);
        expect(ta.view, returnsNormally);
        ta = typeScalars(ta, 'x');
        expect(ta.value, '${cluster}xZ');
        expect(ta.cursorColumn, 2);
      });
    }

    test('backspace after a decomposed e removes it, not the next char', () {
      var ta = typeScalars(TextAreaModel(value: 'Z'), 'e\u0301');
      expect(ta.value, 'e\u0301Z');
      expect(ta.cursorColumn, 1);
      ta = ta.update(_special(KeyCode.backspace)).$1 as TextAreaModel;
      expect(ta.value, 'Z');
      expect(ta.cursorColumn, 0);
    });

    test('merging scalars on a later line keep that line intact', () {
      final ta = typeScalars(
        TextAreaModel(value: 'a\nZ', cursorRow: 1),
        'e\u0301x',
      );
      expect(ta.value, 'a\ne\u0301xZ');
      expect((ta.cursorRow, ta.cursorColumn), (1, 2));
    });
  });

  group('TextAreaModel bracketed paste', () {
    TextAreaModel paste(TextAreaModel ta, String content) =>
        ta.update(PasteMsg(content)).$1 as TextAreaModel;

    test('inserts multi-line text and leaves the cursor after it', () {
      final ta = paste(
        TextAreaModel(value: 'aZ', cursorCol: 1),
        'x\r\ny\rz',
      );
      expect(ta.value, 'ax\ny\nzZ');
      expect((ta.cursorRow, ta.cursorColumn), (2, 1));
    });

    test('turns tabs into one space', () {
      expect(paste(TextAreaModel(), 'a\tb').value, 'a b');
    });

    test('drops control characters so ESC cannot reach the terminal', () {
      final ta = paste(TextAreaModel(), 'a\x1b[31mb\x00\x07\x7fc');
      expect(ta.value, 'a[31mbc');
    });

    test('merges multi-scalar graphemes into the surrounding text', () {
      final ta = paste(
        TextAreaModel(value: 'Z'),
        '\u{1F468}\u200D\u{1F469}',
      );
      expect(ta.value, '\u{1F468}\u200D\u{1F469}Z');
      expect(ta.cursorColumn, 1);
      expect(ta.view, returnsNormally);
    });

    test('truncates to charLimit', () {
      final ta = paste(
          TextAreaModel(value: 'ab', cursorCol: 2, charLimit: 5), 'cdefgh');
      expect(ta.value, 'abcde');
      expect(ta.cursorColumn, 5);
    });

    test('keeps a combining mark that joins at the cursor under charLimit', () {
      final ta = paste(
        TextAreaModel(value: 'aZ', cursorCol: 1, charLimit: 2),
        '\u0301x',
      );
      expect(ta.value, 'a\u0301Z');
      expect(ta.cursorColumn, 1);
    });

    test('keeps a fitting first grapheme when the full paste exceeds charLimit',
        () {
      final ta = paste(TextAreaModel(charLimit: 1), 'ab');
      expect(ta.value, 'a');
      expect(ta.cursorColumn, 1);
    });

    test('truncates to maxContentHeight', () {
      final ta = paste(TextAreaModel(maxContentHeight: 2), 'a\nb\nc\nd');
      expect(ta.value, 'a\nb');
      expect((ta.cursorRow, ta.cursorColumn), (1, 1));
    });

    test('is ignored while unfocused', () {
      final ta = TextAreaModel(value: 'ab', focused: false);
      expect(paste(ta, 'x'), same(ta));
    });

    test('paste start and end markers are ignored', () {
      final ta = TextAreaModel(value: 'ab');
      expect(ta.update(PasteStartMsg()).$1, same(ta));
      expect(ta.update(PasteEndMsg()).$1, same(ta));
    });
  });
}
