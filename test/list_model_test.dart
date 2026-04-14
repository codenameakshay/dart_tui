// Tests for ListModel with fuzzy filtering.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

// Helper to create a KeyMsg from a key string.
KeyMsg _key(String key) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: key));

KeyMsg _namedKey(String name) {
  final code = switch (name) {
    'up' => KeyCode.up,
    'down' => KeyCode.down,
    'enter' => KeyCode.enter,
    'backspace' => KeyCode.backspace,
    'esc' => KeyCode.escape,
    _ => KeyCode.unknown,
  };
  return KeyPressMsg(TeaKey(code: code));
}

void main() {
  final items = [
    const ListItem(title: 'Apple', description: 'A red fruit'),
    const ListItem(title: 'Banana', description: 'A yellow fruit'),
    const ListItem(title: 'Cherry'),
    const ListItem(title: 'Date', description: 'A sweet fruit'),
    const ListItem(title: 'Elderberry'),
  ];

  group('ListModel navigation', () {
    test('initial cursor is at 0', () {
      final m = ListModel(items: items);
      expect(m.cursor, equals(0));
    });

    test('down moves cursor', () {
      final m = ListModel(items: items);
      final (next, _) = m.update(_namedKey('down'));
      expect((next as ListModel).cursor, equals(1));
    });

    test('up at 0 stays at 0', () {
      final m = ListModel(items: items);
      final (next, _) = m.update(_namedKey('up'));
      expect((next as ListModel).cursor, equals(0));
    });

    test('j moves cursor down', () {
      final m = ListModel(items: items);
      final (next, _) = m.update(_key('j'));
      expect((next as ListModel).cursor, equals(1));
    });

    test('k moves cursor up', () {
      final m = ListModel(items: items, cursor: 2);
      final (next, _) = m.update(_key('k'));
      expect((next as ListModel).cursor, equals(1));
    });

    test('down at last item stays at last', () {
      final m = ListModel(items: items, cursor: items.length - 1);
      final (next, _) = m.update(_namedKey('down'));
      expect((next as ListModel).cursor, equals(items.length - 1));
    });

    test('selected returns the item at cursor', () {
      final m = ListModel(items: items, cursor: 2);
      expect(m.selected?.title, equals('Cherry'));
    });

    test('selected returns null when list is empty', () {
      final m = ListModel(items: [const ListItem(title: 'only')]);
      // Force empty filtered list via impossible filter
      final (next, _) = m.update(_key('/'));
      final listNext = next as ListModel;
      final (next2, _) = listNext.update(_key('z'));
      final (next3, _) = (next2 as ListModel).update(_key('z'));
      expect((next3 as ListModel).selected, isNull);
    });
  });

  group('ListModel filter mode', () {
    test('/ enters filter mode', () {
      final m = ListModel(items: items);
      final (next, _) = m.update(_key('/'));
      expect((next as ListModel).filterMode, isTrue);
    });

    test('typing in filter mode narrows items', () {
      final m = ListModel(items: items);
      var (next, _) = m.update(_key('/'));
      for (final char in 'App'.split('')) {
        (next, _) = (next as ListModel).update(_key(char));
      }
      final filtered = (next as ListModel).filteredItems;
      expect(filtered.length, equals(1));
      expect(filtered.first.title, equals('Apple'));
    });

    test('backspace removes last filter character', () {
      final m = ListModel(items: items, filter: 'App', filterMode: true);
      final (next, _) = m.update(_namedKey('backspace'));
      expect((next as ListModel).filter, equals('Ap'));
    });

    test('backspace on empty filter exits filter mode', () {
      final m = ListModel(items: items, filter: '', filterMode: true);
      final (next, _) = m.update(_namedKey('backspace'));
      expect((next as ListModel).filterMode, isFalse);
    });

    test('esc in filter mode clears filter', () {
      final m = ListModel(items: items, filter: 'App', filterMode: true);
      final (next, _) = m.update(_namedKey('esc'));
      final nm = next as ListModel;
      expect(nm.filter, equals(''));
      expect(nm.filterMode, isFalse);
    });

    test('enter in filter mode exits filter mode, keeps filter', () {
      final m = ListModel(items: items, filter: 'App', filterMode: true);
      final (next, _) = m.update(_namedKey('enter'));
      final nm = next as ListModel;
      expect(nm.filterMode, isFalse);
      expect(nm.filter, equals('App'));
    });

    test('esc in normal mode with filter clears filter', () {
      final m = ListModel(items: items, filter: 'App', filterMode: false);
      final (next, _) = m.update(_namedKey('esc'));
      expect((next as ListModel).filter, equals(''));
    });

    test('filter resets cursor to 0', () {
      final m = ListModel(items: items, cursor: 3, filterMode: true);
      final (next, _) = m.update(_key('a'));
      expect((next as ListModel).cursor, equals(0));
    });
  });

  group('ListModel fuzzy match', () {
    test('matches prefix', () {
      final m = ListModel(items: items, filter: 'App');
      expect(m.filteredItems.map((i) => i.title), contains('Apple'));
    });

    test('matches subsequence', () {
      final m = ListModel(items: items, filter: 'at');
      // 'Date' contains 'a' then 't' — should match
      expect(m.filteredItems.map((i) => i.title), contains('Date'));
    });

    test('no match returns empty list', () {
      final m = ListModel(items: items, filter: 'zzz');
      expect(m.filteredItems, isEmpty);
    });

    test('empty filter returns all items', () {
      final m = ListModel(items: items);
      expect(m.filteredItems.length, equals(items.length));
    });

    test('filter is case-insensitive', () {
      final m = ListModel(items: items, filter: 'apple');
      expect(m.filteredItems.map((i) => i.title), contains('Apple'));
    });
  });

  group('ListModel view', () {
    test('view contains item titles', () {
      final m = ListModel(items: items);
      final v = m.view();
      expect(v.content, contains('Apple'));
      expect(v.content, contains('Banana'));
    });

    test('view contains filter input when in filter mode', () {
      final m = ListModel(items: items, filter: 'Ban', filterMode: true);
      final v = m.view();
      expect(v.content, contains('Ban'));
    });

    test('view contains status bar by default', () {
      final m = ListModel(items: items, showStatusBar: true);
      expect(m.view().content, contains('items'));
    });

    test('view shows filtered count in status bar', () {
      final m = ListModel(items: items, filter: 'App', showStatusBar: true);
      final v = m.view();
      expect(v.content, contains('1/5 items'));
    });

    test('view shows description when showDescription is true', () {
      final m = ListModel(items: items, showDescription: true);
      expect(m.view().content, contains('A red fruit'));
    });

    test('view hides description when showDescription is false', () {
      final m = ListModel(items: items, showDescription: false);
      expect(m.view().content, isNot(contains('A red fruit')));
    });

    test('view shows title when provided', () {
      final m = ListModel(items: items, title: 'My List');
      expect(m.view().content, contains('My List'));
    });
  });
}
