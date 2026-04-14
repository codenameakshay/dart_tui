import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));
KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));

void main() {
  group('SelectListModel', () {
    SelectListModel make({bool wrap = false}) => SelectListModel(
          items: ['Alpha', 'Beta', 'Gamma'],
          wrap: wrap,
        );

    test('initial cursor is 0', () {
      expect(make().cursor, 0);
    });

    test('down arrow moves cursor down', () {
      final (next, _) = make().update(_special(KeyCode.down));
      expect((next as SelectListModel).cursor, 1);
    });

    test('up arrow does not go below 0 without wrap', () {
      final (next, _) = make().update(_special(KeyCode.up));
      expect((next as SelectListModel).cursor, 0);
    });

    test('down arrow stops at last item without wrap', () {
      var s = make();
      s = (s.update(_special(KeyCode.down)).$1 as SelectListModel);
      s = (s.update(_special(KeyCode.down)).$1 as SelectListModel);
      final (next, _) = s.update(_special(KeyCode.down));
      expect((next as SelectListModel).cursor, 2);
    });

    test('j/k keys navigate', () {
      final (next1, _) = make().update(_char('j'));
      expect((next1 as SelectListModel).cursor, 1);
      final (next2, _) = next1.update(_char('k'));
      expect((next2 as SelectListModel).cursor, 0);
    });

    test('wrap=true: up at 0 wraps to last', () {
      final s = make(wrap: true);
      final (next, _) = s.update(_special(KeyCode.up));
      expect((next as SelectListModel).cursor, 2);
    });

    test('wrap=true: down at last wraps to 0', () {
      var s = make(wrap: true);
      s = (s.update(_special(KeyCode.down)).$1 as SelectListModel);
      s = (s.update(_special(KeyCode.down)).$1 as SelectListModel);
      final (next, _) = s.update(_special(KeyCode.down));
      expect((next as SelectListModel).cursor, 0);
    });

    test('view renders all items', () {
      final content = make().view().content;
      expect(content, contains('Alpha'));
      expect(content, contains('Beta'));
      expect(content, contains('Gamma'));
    });

    test('view shows cursor on selected item', () {
      final s = SelectListModel(items: ['A', 'B'], cursor: 1);
      final lines = s.view().content.split('\n');
      // Second item should have cursor indicator
      expect(lines[1], contains('›'));
    });

    test('view shows optional title', () {
      final s = SelectListModel(items: ['X'], title: 'Pick one');
      expect(s.view().content, contains('Pick one'));
    });

    test('non-navigation msgs are ignored', () {
      final s = make();
      final (next, _) = s.update(TickMsg(DateTime.now()));
      expect(identical(s, next), isTrue);
    });
  });
}
