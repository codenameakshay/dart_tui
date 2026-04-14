import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('CursorModel', () {
    test('initial state: visible, focused, block mode', () {
      final c = CursorModel();
      expect(c.visible, isTrue);
      expect(c.focused, isTrue);
      expect(c.mode, CursorMode.block);
    });

    test('TickMsg toggles visibility when blink is true', () {
      final c = CursorModel(blink: true, visible: true);
      final (next, _) = c.update(TickMsg(DateTime.now()));
      expect((next as CursorModel).visible, isFalse);
      final (next2, _) = next.update(TickMsg(DateTime.now()));
      expect((next2 as CursorModel).visible, isTrue);
    });

    test('TickMsg does nothing when blink is false', () {
      final c = CursorModel(blink: false, visible: true);
      final (next, _) = c.update(TickMsg(DateTime.now()));
      expect((next as CursorModel).visible, isTrue);
    });

    test('TickMsg does nothing when not focused', () {
      final c = CursorModel(focused: false, visible: true);
      final (next, _) = c.update(TickMsg(DateTime.now()));
      expect(identical(c, next), isTrue);
    });

    test('view when visible renders block char', () {
      final c = CursorModel(mode: CursorMode.block, visible: true);
      expect(c.view().content, contains('█'));
    });

    test('view when invisible renders space', () {
      final c = CursorModel(visible: false);
      expect(c.view().content, ' ');
    });

    test('underline mode renders underscore', () {
      final c = CursorModel(mode: CursorMode.underline, visible: true);
      expect(c.view().content, contains('_'));
    });

    test('bar mode renders pipe', () {
      final c = CursorModel(mode: CursorMode.bar, visible: true);
      expect(c.view().content, contains('|'));
    });

    test('blur() returns unfocused copy', () {
      final c = CursorModel().blur();
      expect(c.focused, isFalse);
    });

    test('focus() returns focused copy', () {
      final c = CursorModel().blur().focus();
      expect(c.focused, isTrue);
    });

    test('withMode changes mode', () {
      final c = CursorModel().withMode(CursorMode.bar);
      expect(c.mode, CursorMode.bar);
    });

    test('non-Tick msgs are ignored when focused', () {
      final c = CursorModel();
      final (next, _) = c.update(KeyPressMsg(TeaKey(code: KeyCode.rune, text: 'a')));
      expect(identical(c, next), isTrue);
    });
  });
}
