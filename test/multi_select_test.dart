import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));
KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));

MultiSelectModel _make({bool wrap = false}) => MultiSelectModel(
      items: [
        const MultiSelectItem(label: 'Dart'),
        const MultiSelectItem(label: 'Go'),
        const MultiSelectItem(label: 'Rust'),
      ],
      wrap: wrap,
    );

void main() {
  group('MultiSelectModel', () {
    test('initial state: nothing selected, cursor at 0', () {
      final m = _make();
      expect(m.cursor, 0);
      expect(m.selected, isEmpty);
    });

    test('down/up navigation changes cursor', () {
      final (next1, _) = _make().update(_special(KeyCode.down));
      expect((next1 as MultiSelectModel).cursor, 1);
      final (next2, _) = next1.update(_special(KeyCode.up));
      expect((next2 as MultiSelectModel).cursor, 0);
    });

    test('j/k keys navigate', () {
      final (next1, _) = _make().update(_char('j'));
      expect((next1 as MultiSelectModel).cursor, 1);
      final (next2, _) = next1.update(_char('k'));
      expect((next2 as MultiSelectModel).cursor, 0);
    });

    test('Space toggles selection on current item', () {
      final (next, _) = _make().update(_special(KeyCode.space));
      final m = next as MultiSelectModel;
      expect(m.items[0].selected, isTrue);
      expect(m.selected.length, 1);
    });

    test('x also toggles selection', () {
      final (next, _) = _make().update(_char('x'));
      final m = next as MultiSelectModel;
      expect(m.items[0].selected, isTrue);
    });

    test('toggling twice deselects', () {
      var m = _make();
      m = (m.update(_char(' ')).$1 as MultiSelectModel);
      m = (m.update(_char(' ')).$1 as MultiSelectModel);
      expect(m.items[0].selected, isFalse);
    });

    test('a toggles all items on', () {
      final (next, _) = _make().update(_char('a'));
      final m = next as MultiSelectModel;
      expect(m.items.every((i) => i.selected), isTrue);
    });

    test('a when all selected toggles all off', () {
      // First select all
      final (all, _) = _make().update(_char('a'));
      // Then toggle all off
      final (none, _) = (all as MultiSelectModel).update(_char('a'));
      final m = none as MultiSelectModel;
      expect(m.items.every((i) => !i.selected), isTrue);
    });

    test('wrap=true: up at 0 wraps to last', () {
      final (next, _) = _make(wrap: true).update(_special(KeyCode.up));
      expect((next as MultiSelectModel).cursor, 2);
    });

    test('wrap=true: down at last wraps to 0', () {
      var m = _make(wrap: true);
      m = (m.update(_special(KeyCode.down)).$1 as MultiSelectModel);
      m = (m.update(_special(KeyCode.down)).$1 as MultiSelectModel);
      final (next, _) = m.update(_special(KeyCode.down));
      expect((next as MultiSelectModel).cursor, 0);
    });

    test('selectedValues returns label when value is empty', () {
      var m = _make();
      m = (m.update(_char(' ')).$1 as MultiSelectModel);
      expect(m.selectedValues, ['Dart']);
    });

    test('selectedValues returns custom value when set', () {
      final m = MultiSelectModel(items: [
        const MultiSelectItem(label: 'Dart', value: 'dart-lang', selected: true),
      ]);
      expect(m.selectedValues, ['dart-lang']);
    });

    test('view contains all labels', () {
      final content = _make().view().content;
      expect(content, contains('Dart'));
      expect(content, contains('Go'));
      expect(content, contains('Rust'));
    });

    test('view shows checked box for selected items', () {
      var m = _make();
      m = (m.update(_char(' ')).$1 as MultiSelectModel);
      expect(m.view().content, contains('[x]'));
    });

    test('view shows unchecked box for unselected items', () {
      expect(_make().view().content, contains('[ ]'));
    });

    test('status bar shows count', () {
      var m = _make();
      m = (m.update(_char(' ')).$1 as MultiSelectModel);
      expect(m.view().content, contains('1/3 selected'));
    });

    test('non-navigation msgs are ignored', () {
      final m = _make();
      final (next, _) = m.update(TickMsg(DateTime.now()));
      expect(identical(m, next), isTrue);
    });
  });
}
