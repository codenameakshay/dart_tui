import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _k(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg _r(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));
KeyPressMsg _ctrl(String t) => KeyPressMsg(
    TeaKey(code: KeyCode.rune, text: t, modifiers: const {KeyMod.ctrl}));

T _u<T>(TeaModel m, KeyMsg k) => m.update(k).$1 as T;

void main() {
  group('TextAreaModel', () {
    test('ignores non-key messages', () {
      final m = TextAreaModel(value: 'a');
      expect(m.update(WindowSizeMsg(4, 4)).$1, same(m));
    });

    test('typing inserts and enter splits into a new line', () {
      var m = TextAreaModel();
      m = _u(m, _r('h'));
      m = _u(m, _r('i'));
      expect(m.value, 'hi');
      m = _u(m, _k(KeyCode.enter));
      expect(m.lines, ['hi', '']);
      expect(m.cursorRow, 1);
    });

    test('backspace merges into the previous line', () {
      var m = TextAreaModel(value: 'ab\ncd', cursorRow: 1, cursorCol: 0);
      m = _u(m, _k(KeyCode.backspace));
      expect(m.value, 'abcd');
      expect(m.cursorRow, 0);
      expect(m.cursorCol, 2);
    });

    test('delete-forward at line end merges the next line', () {
      var m = TextAreaModel(value: 'ab\ncd', cursorRow: 0, cursorCol: 2);
      m = _u(m, _k(KeyCode.delete));
      expect(m.value, 'abcd');
    });

    test('up/down move rows with column clamping; edges are no-ops', () {
      var m = TextAreaModel(value: 'abcd\nef', cursorRow: 0, cursorCol: 4);
      expect(m.update(_k(KeyCode.up)).$1, same(m)); // row 0 up = no-op
      m = _u(m, _k(KeyCode.down));
      expect(m.cursorRow, 1);
      expect(m.cursorCol, 2); // clamped to 'ef'.length
      expect(m.update(_k(KeyCode.down)).$1, same(m)); // last row down = no-op
    });

    test('left wraps to previous line end; right wraps to next line start', () {
      var m = TextAreaModel(value: 'ab\ncd', cursorRow: 1, cursorCol: 0);
      m = _u(m, _k(KeyCode.left));
      expect(m.cursorRow, 0);
      expect(m.cursorCol, 2);
      m = _u(m, _k(KeyCode.right));
      expect(m.cursorRow, 1);
      expect(m.cursorCol, 0);
    });

    test('home/end and ctrl+k/ctrl+u kill line segments', () {
      var m = TextAreaModel(value: 'hello', cursorCol: 5);
      expect(_u<TextAreaModel>(m, _k(KeyCode.home)).cursorCol, 0);
      expect(_u<TextAreaModel>(m, _k(KeyCode.end)).cursorCol, 5);
      m = TextAreaModel(value: 'hello', cursorCol: 2);
      expect(_u<TextAreaModel>(m, _ctrl('k')).value, 'he'); // kill to end
      expect(_u<TextAreaModel>(m, _ctrl('u')).value, 'llo'); // kill to start
    });

    test('charLimit blocks insert and enter', () {
      final m = TextAreaModel(value: 'ab', cursorCol: 2, charLimit: 2);
      expect(_u<TextAreaModel>(m, _r('c')).value, 'ab');
      expect(m.update(_k(KeyCode.enter)).$1, same(m));
    });

    test('view shows placeholder when empty+unfocused, else the text', () {
      expect(TextAreaModel(focused: false, placeholder: 'ph').view().content,
          contains('ph'));
      expect(TextAreaModel(value: 'x\ny').view().content, contains('x'));
    });
  });

  group('ViewportModel navigation', () {
    ViewportModel long() => ViewportModel(
        content: List.generate(30, (i) => 'row$i').join('\n'),
        width: 80,
        height: 5);

    test('ignores non-key messages', () {
      final m = long();
      expect(m.update(WindowSizeMsg(4, 4)).$1, same(m));
    });

    test('home/g to top, end/G to bottom', () {
      var m = long().scrollBy(10);
      m = _u(m, _r('g'));
      expect(m.atTop, isTrue);
      m = _u(m, _r('G'));
      expect(m.atBottom, isTrue);
    });

    test('pgdown/space then pgup move by a page', () {
      var m = long();
      m = _u(m, _k(KeyCode.pageDown));
      expect(m.yOffset, 5);
      m = _u(m, _k(KeyCode.space));
      expect(m.yOffset, 10);
      m = _u(m, _k(KeyCode.pageUp));
      expect(m.yOffset, 5);
    });

    test('ctrl+b / ctrl+f page too', () {
      var m = long();
      m = _u(m, _ctrl('f'));
      expect(m.yOffset, 5);
      m = _u(m, _ctrl('b'));
      expect(m.yOffset, 0);
    });

    test('non-softwrap left/right pan the horizontal offset and truncate', () {
      var m = ViewportModel(
          content: 'abcdef', width: 3, height: 2, softWrap: false);
      m = _u(m, _k(KeyCode.right));
      expect(m.xOffset, 1);
      expect(m.view().content, 'bcdef');
      m = _u(m, _k(KeyCode.left));
      expect(m.xOffset, 0);
    });

    test('softwrap left/right are ignored', () {
      final m = ViewportModel(content: 'abc', width: 2, softWrap: true);
      expect(m.update(_k(KeyCode.left)).$1, same(m));
      expect(m.update(_k(KeyCode.right)).$1, same(m));
    });

    test('scrollPercent is 1.0 when content fits', () {
      final m = ViewportModel(content: 'one', height: 24);
      expect(m.scrollPercent, 1.0);
    });
  });

  group('ListModel filter + navigation', () {
    ListModel base() => ListModel(
          items: [
            const ListItem(title: 'apple', description: 'red'),
            const ListItem(title: 'banana'),
            const ListItem(title: 'apricot'),
            const ListItem(title: 'cherry'),
          ],
          height: 2,
        );

    test('slash enters filter mode; typing filters; enter keeps it', () {
      var m = _u<ListModel>(base(), _r('/'));
      expect(m.filterMode, isTrue);
      m = _u(m, _r('a'));
      m = _u(m, _r('p'));
      expect(m.filter, 'ap');
      expect(m.filteredItems.map((i) => i.title), ['apple', 'apricot']);
      m = _u(m, _k(KeyCode.enter));
      expect(m.filterMode, isFalse);
      expect(m.filter, 'ap');
    });

    test('backspace shortens filter; empty backspace exits filter mode', () {
      var m = _u<ListModel>(base(), _r('/'));
      m = _u(m, _r('a'));
      m = _u(m, _k(KeyCode.backspace));
      expect(m.filter, '');
      m = _u(m, _k(KeyCode.backspace));
      expect(m.filterMode, isFalse);
    });

    test('esc in filter mode clears the query', () {
      var m = _u<ListModel>(base(), _r('/'));
      m = _u(m, _r('x'));
      m = _u(m, _k(KeyCode.escape));
      expect(m.filterMode, isFalse);
      expect(m.filter, '');
    });

    test('esc clears an active filter outside filter mode', () {
      final filtered = ListModel(items: base().items, filter: 'ap');
      final cleared = _u<ListModel>(filtered, _k(KeyCode.escape));
      expect(cleared.filter, '');
    });

    test('j/k, pgdown/pgup, g/G navigate with clamping', () {
      var m = base();
      m = _u(m, _r('j'));
      expect(m.cursor, 1);
      m = _u(m, _r('k'));
      expect(m.cursor, 0);
      m = _u(m, _k(KeyCode.pageDown));
      expect(m.cursor, 2);
      m = _u(m, _r('G'));
      expect(m.cursor, 3);
      m = _u(m, _r('g'));
      expect(m.cursor, 0);
    });

    test('mouse wheel and left-click move/select the cursor', () {
      var m = base();
      m = m
          .update(MouseClickMsg(
              const Mouse(x: 0, y: 0, button: MouseButton.wheelDown)))
          .$1 as ListModel;
      expect(m.cursor, 1);
      m = m
          .update(MouseClickMsg(
              const Mouse(x: 0, y: 0, button: MouseButton.wheelUp)))
          .$1 as ListModel;
      expect(m.cursor, 0);
      final clicked = m
          .update(
              MouseClickMsg(const Mouse(x: 0, y: 0, button: MouseButton.left)))
          .$1 as ListModel;
      expect(clicked.cursor, isNonNegative);
    });

    test('view renders title, filter bar, items, and no-results', () {
      expect(base().view().content, contains('apple'));
      final filtered = ListModel(items: base().items, filter: 'zzz');
      expect(filtered.view().content, contains('No results'));
      final titled = ListModel(items: base().items, title: 'Fruit');
      expect(titled.view().content, contains('Fruit'));
    });
  });
}
