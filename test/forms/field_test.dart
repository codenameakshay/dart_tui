import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg key(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg rune(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));

void main() {
  group('input field', () {
    test('edits value and validates', () {
      var f = Field.input(
          key: 'name',
          title: 'Name',
          validate: (v) => v.contains(' ') ? 'no spaces' : null);
      expect(f.value, '');
      f = f.updateEditor(rune('a')).updateEditor(rune('b'));
      expect(f.value, 'ab');
      expect(f.validate(), isNull);
      f = f.updateEditor(rune(' '));
      expect(f.validate(), 'no spaces');
      expect(f.acceptsInput, isTrue);
      expect(f.key, 'name');
    });

    test('password renders bullets', () {
      final f = Field.password(key: 'pw', title: 'Pw').updateEditor(rune('x'));
      final out = f.render(true, FormStyles.defaults, FormValues.empty);
      expect(out, contains('•'));
      expect(out, isNot(contains('x')));
    });
  });

  group('text field', () {
    test('multiline value; enter inserts newline via editor', () {
      var f = Field.text(key: 'body', title: 'Body', initial: 'a');
      f = f.updateEditor(key(KeyCode.enter)).updateEditor(rune('b'));
      expect(f.value, 'a\nb');
    });
  });

  group('note field', () {
    test('has no key/value and rejects input', () {
      final f = Field.note(title: 'Hi', description: 'read me');
      expect(f.key, isNull);
      expect(f.value, isNull);
      expect(f.acceptsInput, isFalse);
      expect(f.render(false, FormStyles.defaults, FormValues.empty),
          contains('read me'));
    });
  });

  test('titleFor resolves from values', () {
    final f = Field.input(key: 'x', titleFor: (v) => 'Hi ${v.get('n')}');
    expect(f.titleText(const FormValues({'n': 'ada'})), 'Hi ada');
  });

  test('hidden resolves from values', () {
    final f =
        Field.input(key: 'x', title: 'X', hidden: (v) => v.get('h') == true);
    expect(f.isHidden(const FormValues({'h': true})), isTrue);
    expect(f.isHidden(const FormValues({'h': false})), isFalse);
  });
}
