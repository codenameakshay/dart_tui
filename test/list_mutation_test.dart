import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('ListModel runtime mutation API', () {
    ListModel base() =>
        ListModel(items: const [ListItem(title: 'a'), ListItem(title: 'b')]);

    test('append / insert / setItemAt grow and edit the list', () {
      var m = base().appendItem(const ListItem(title: 'c'));
      expect(m.items.map((i) => i.title), ['a', 'b', 'c']);
      m = m.insertItem(0, const ListItem(title: 'z'));
      expect(m.items.first.title, 'z');
      m = m.setItemAt(0, const ListItem(title: 'zz'));
      expect(m.items.first.title, 'zz');
    });

    test('removeItemAt shrinks and clamps the cursor; out-of-range is a no-op',
        () {
      var m = base().appendItem(const ListItem(title: 'c')).select(2);
      expect(m.selectedIndex, 2);
      m = m.removeItemAt(2);
      expect(m.items.length, 2);
      expect(m.selectedIndex, 1); // cursor clamped down
      expect(m.removeItemAt(9).items.length, 2); // no-op
      expect(m.setItemAt(9, const ListItem(title: 'x')).items.length, 2);
    });

    test('select clamps and withItems([]) resets cursor', () {
      final m = base().select(99);
      expect(m.selectedIndex, 1);
      final empty = m.withItems(const []);
      expect(empty.items, isEmpty);
      expect(empty.selectedIndex, 0);
    });
  });
}
