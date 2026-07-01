import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg key(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg rune(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));
KeyPressMsg shiftTab() =>
    KeyPressMsg(const TeaKey(code: KeyCode.tab, modifiers: {KeyMod.shift}));
KeyPressMsg ctrlD() => KeyPressMsg(
    const TeaKey(code: KeyCode.rune, text: 'd', modifiers: {KeyMod.ctrl}));
Form step(Form f, KeyMsg m) => f.update(m).$1 as Form;

void main() {
  test('tab/shift+tab move focus; notes are skipped; enter submits at end', () {
    var f = Form([
      Group([
        Field.input(key: 'a', title: 'A'),
        Field.note(title: 'divider'),
        Field.input(key: 'b', title: 'B'),
      ]),
    ]);
    f = step(f, rune('x')); // edits field a
    expect(f.values.get<String>('a'), 'x');
    f = step(f, key(KeyCode.tab)); // → skips note → field b
    f = step(f, rune('y'));
    expect(f.values.get<String>('b'), 'y');
    f = step(f, key(KeyCode.tab)); // past last field → submit
    expect(f.submitted, isTrue);
  });

  test('shift+tab at first field is a no-op', () {
    final f = Form([
      Group([Field.input(key: 'a', title: 'A')])
    ]);
    final same = step(f, shiftTab());
    expect(same.fieldIndexForTest, 0);
  });

  test('enter inserts newline in text field; ctrl+d advances', () {
    var f = Form([
      Group([
        Field.text(key: 'body', title: 'Body'),
        Field.input(key: 'after', title: 'After'),
      ]),
    ]);
    f = step(f, rune('a'));
    f = step(f, key(KeyCode.enter)); // newline, not advance
    f = step(f, rune('b'));
    expect(f.values.get<String>('body'), 'a\nb');
    f = step(f, ctrlD()); // advance
    f = step(f, rune('Z'));
    expect(f.values.get<String>('after'), 'Z');
  });
}
