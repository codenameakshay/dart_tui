import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _k(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg _rune(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));

TextInputModel _apply(TextInputModel m, KeyMsg msg) =>
    m.update(msg).$1 as TextInputModel;

void main() {
  group('TextInputModel editing', () {
    test('non-key message is ignored', () {
      final m = TextInputModel(value: 'x');
      expect(m.update(WindowSizeMsg(10, 10)).$1, same(m));
    });

    test('typing inserts at the cursor', () {
      var m = TextInputModel();
      m = _apply(m, _rune('h'));
      m = _apply(m, _rune('i'));
      expect(m.value, 'hi');
      expect(m.cursorPos, 2);
    });

    test('insert in the middle', () {
      var m = TextInputModel(value: 'ac', cursorPos: 1);
      m = _apply(m, _rune('b'));
      expect(m.value, 'abc');
      expect(m.cursorPos, 2);
    });

    test('backspace removes before cursor; no-op at start/empty', () {
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 2),
                  _k(KeyCode.backspace))
              .value,
          'a');
      expect(
          TextInputModel(value: 'ab', cursorPos: 0)
              .update(_k(KeyCode.backspace))
              .$1,
          isA<TextInputModel>().having((m) => m.value, 'value', 'ab'));
      expect(TextInputModel().update(_k(KeyCode.backspace)).$1,
          isA<TextInputModel>().having((m) => m.value, 'value', ''));
    });

    test('delete removes at cursor; no-op at end', () {
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 0), _k(KeyCode.delete))
              .value,
          'b');
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 2), _k(KeyCode.delete))
              .value,
          'ab');
    });

    test('left/right/home/end move the cursor with clamping', () {
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 2), _k(KeyCode.left))
              .cursorPos,
          1);
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 0), _k(KeyCode.left))
              .cursorPos,
          0);
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 0), _k(KeyCode.right))
              .cursorPos,
          1);
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 2), _k(KeyCode.right))
              .cursorPos,
          2);
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 1), _k(KeyCode.home))
              .cursorPos,
          0);
      expect(
          _apply(TextInputModel(value: 'ab', cursorPos: 0), _k(KeyCode.end))
              .cursorPos,
          2);
    });

    test('charLimit blocks further input', () {
      final m = TextInputModel(value: 'ab', cursorPos: 2, charLimit: 2);
      expect(_apply(m, _rune('c')).value, 'ab');
    });

    test('unfocused ignores typing', () {
      final m = TextInputModel(focused: false);
      expect(_apply(m, _rune('a')).value, '');
    });

    test('esc is a no-op', () {
      final m = TextInputModel(value: 'a');
      expect(m.update(_k(KeyCode.escape)).$1, same(m));
    });
  });

  group('TextInputModel validation', () {
    test('enter with passing validator does not emit', () {
      final m = TextInputModel(value: 'abc', validate: (v) => v.length >= 3);
      final (_, cmd) = m.update(_k(KeyCode.enter));
      expect(cmd, isNull);
    });

    test('enter with failing validator emits ValidationFailedMsg', () async {
      final m = TextInputModel(value: 'ab', validate: (v) => v.length >= 3);
      final (_, cmd) = m.update(_k(KeyCode.enter));
      expect(cmd, isNotNull);
      final produced = await cmd!();
      expect(produced, isA<ValidationFailedMsg>());
      expect((produced as ValidationFailedMsg).value, 'ab');
    });

    test('enter with no validator is a no-op', () {
      final m = TextInputModel(value: 'x');
      expect(m.update(_k(KeyCode.enter)).$1, same(m));
    });
  });

  group('TextInputModel suggestions', () {
    test('tab accepts the active suggestion', () {
      final m = TextInputModel(value: 'ap', suggestions: ['apple', 'apricot']);
      final next = _apply(m, _k(KeyCode.tab));
      expect(next.value, 'apple');
      expect(next.cursorPos, 5);
    });

    test('tab with no matching suggestion is a no-op', () {
      final m = TextInputModel(value: 'zz', suggestions: ['apple']);
      expect(m.update(_k(KeyCode.tab)).$1, same(m));
    });
  });

  group('TextInputModel view', () {
    test('unfocused empty shows placeholder (with and without label)', () {
      expect(
          TextInputModel(focused: false, placeholder: 'type…').view().content,
          contains('type…'));
      final withLabel =
          TextInputModel(focused: false, placeholder: 'x', label: 'Name')
              .view();
      expect(withLabel.content, contains('Name'));
    });

    test('normal echo shows the value and sets a bar cursor', () {
      final v = TextInputModel(value: 'ab', cursorPos: 1).view();
      expect(v.content, contains('ab'));
      expect(v.cursor, isNotNull);
      expect(v.cursor!.shape, CursorShape.bar);
      expect(v.cursor!.x, 1);
    });

    test('password echo shows bullets', () {
      final v =
          TextInputModel(value: 'abc', echoMode: EchoMode.password).view();
      expect(v.content, contains('•••'));
      expect(v.content, isNot(contains('abc')));
    });

    test('none echo shows nothing for the value', () {
      final v = TextInputModel(value: 'secret', echoMode: EchoMode.none).view();
      expect(v.content, isNot(contains('secret')));
    });

    test('suggestion suffix is rendered after the value', () {
      final v = TextInputModel(value: 'ap', suggestions: ['apple']).view();
      expect(v.content, contains('ple'));
    });

    test('double-width label offsets the cursor', () {
      final v = TextInputModel(value: '你', cursorPos: 1, label: 'X').view();
      // label 'X' + space = width 2, plus one double-width char = 2 → x == 4
      expect(v.cursor!.x, 4);
    });
  });
}
