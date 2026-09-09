import 'package:test/test.dart';

import 'package:dart_tui/src/bubbles/style.dart';
import 'package:dart_tui/src/bubbles/canvas.dart';
import 'package:dart_tui/src/bubbles/text_area.dart';
import 'package:dart_tui/src/msg.dart';

void main() {
  test('text area keeps public lines independent', () {
    final model = TextAreaModel(value: 'a\nb');
    final lines = model.lines;
    lines[0] = 'changed';
    expect(model.lines, ['a', 'b']);
  });

  test('text area invalidates visual rows after edits', () {
    final before = TextAreaModel(value: 'abc', width: 2);
    expect(before.visualLineCount, 2);
    final after = before
        .update(
          KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'd')),
        )
        .$1 as TextAreaModel;
    expect(after.value, 'dabc');
    expect(after.visualLineCount, 2);
    expect(stripAnsi(after.view().content), 'da\nbc');
  });

  test('text area invalidates visual rows after resize', () {
    final model = TextAreaModel(value: 'abcd', width: 4);
    expect(model.visualLineCount, 1);
    expect(model.copyWith(width: 2).visualLineCount, 2);
  });

  test('canvas clips long styled lines without changing visible output', () {
    final canvas = Canvas(8, 1);
    canvas.paint(0, 0, '\x1b[31m${'x' * 20000}\x1b[0m');
    expect(stripAnsi(canvas.render()), 'x' * 8);
  });

  test('canvas preserves the final style across adjacent escape codes', () {
    final canvas = Canvas(1, 1);
    canvas.paint(0, 0, '\x1b[31m' * 1000 + 'x');
    expect(stripAnsi(canvas.render()), 'x');
  });
}
