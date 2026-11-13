import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Drives [body] (a prompt helper) with the test harness.
TuiTester _drive(Future<Object?> Function() body) {
  final t = TuiTester.run(body);
  addTearDown(t.dispose);
  return t;
}

void main() {
  group('promptSelect', () {
    test('down + enter selects the second choice', () async {
      final t = _drive(() => promptSelect(['a', 'b', 'c']));
      expectScreen(t.screen, 'test/goldens/prompt_select.txt');
      await t.press('down');
      expectScreen(t.screen, 'test/goldens/prompt_select_down.txt');
      await t.press('enter');
      expect((await t.done()).value, 'b');
    });

    test('ctrl+c cancels and returns null', () async {
      final t = _drive(() => promptSelect(['a', 'b', 'c']));
      await t.press('ctrl+c');
      expect((await t.done()).value, isNull);
    });

    test('empty choices returns null immediately', () async {
      expect(await promptSelect([]), isNull);
    });
  });

  group('promptConfirm', () {
    for (final (key, want) in [
      ('y', true),
      ('n', false),
      ('enter', false), // the default is no
      ('ctrl+c', null),
    ]) {
      test('$key returns $want', () async {
        final t = _drive(() => promptConfirm('ok?'));
        expectScreen(t.screen, 'test/goldens/prompt_confirm.txt');
        await t.press(key);
        expect((await t.done()).value, want);
      });
    }

    test('LF (ctrl+j on some terminals) takes the default, no', () async {
      final t = _drive(() => promptConfirm('ok?'));
      await t.type('\n');
      expect((await t.done()).value, isFalse);
    });
  });

  test('Form.run submits the current confirm value on Enter and LF', () async {
    for (final initial in [true, false]) {
      for (final key in ['\r', '\n']) {
        final form = Form([
          Group([Field.confirm(key: 'ok', title: 'OK?', initial: initial)]),
        ]);
        final t = _drive(form.run);
        await t.type(key);
        final values = (await t.done()).value as FormValues;
        expect(values.get<bool>('ok'), initial,
            reason: 'initial: $initial, key: ${key.codeUnits}');
      }
    }
  });

  group('promptInput', () {
    test('accepts and backspaces an entire emoji grapheme', () async {
      final t = _drive(() => promptInput('name'));
      await t.type('a😀');
      expect(t.screen, 'name a😀█');
      await t.press('backspace');
      await t.press('enter');
      expect((await t.done()).value, 'a');
    });

    test('typing then enter returns the value', () async {
      final t = _drive(() => promptInput('name'));
      await t.type('hi');
      expectScreen(t.screen, 'test/goldens/prompt_input.txt');
      await t.press('enter');
      expect((await t.done()).value, 'hi');
    });

    test('backspace deletes before enter', () async {
      final t = _drive(() => promptInput('name'));
      await t.type('hi');
      await t.press('backspace');
      await t.press('enter');
      expect((await t.done()).value, 'h');
    });

    test('accepts a space between words', () async {
      final t = _drive(() => promptInput('name'));
      await t.type('a b');
      await t.press('enter');
      expect((await t.done()).value, 'a b');
    });

    test('accepts bracketed paste and sanitizes line breaks and controls',
        () async {
      final t = _drive(() => promptInput('name'));
      await t.paste('a\r\nb\tc\x00\x07\x7f\u0085d');
      await t.press('enter');
      expect((await t.done()).value, 'a b cd');
    });

    test('ctrl+c cancels', () async {
      final t = _drive(() => promptInput('name'));
      await t.press('ctrl+c');
      expect((await t.done()).value, isNull);
    });
  });
}
