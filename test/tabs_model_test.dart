// Tests for TabsModel component.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyMsg _key(String key) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: key));

KeyMsg _namedKey(String name) {
  final code = switch (name) {
    'left' => KeyCode.left,
    'right' => KeyCode.right,
    'tab' => KeyCode.tab,
    _ => KeyCode.unknown,
  };
  return KeyPressMsg(TeaKey(code: code));
}

void main() {
  final tabs = [
    ('Home', 'Home content'),
    ('Profile', 'Profile content'),
    ('Settings', 'Settings content'),
  ];

  group('TabsModel navigation', () {
    test('initial active tab is 0', () {
      final m = TabsModel(tabs: tabs);
      expect(m.activeTab, equals(0));
    });

    test('right moves to next tab', () {
      final m = TabsModel(tabs: tabs);
      final (next, _) = m.update(_namedKey('right'));
      expect((next as TabsModel).activeTab, equals(1));
    });

    test('left at first tab stays at 0', () {
      final m = TabsModel(tabs: tabs);
      final (next, _) = m.update(_namedKey('left'));
      expect((next as TabsModel).activeTab, equals(0));
    });

    test('right at last tab stays at last', () {
      final m = TabsModel(tabs: tabs, activeTab: 2);
      final (next, _) = m.update(_namedKey('right'));
      expect((next as TabsModel).activeTab, equals(2));
    });

    test('l moves right', () {
      final m = TabsModel(tabs: tabs);
      final (next, _) = m.update(_key('l'));
      expect((next as TabsModel).activeTab, equals(1));
    });

    test('h moves left', () {
      final m = TabsModel(tabs: tabs, activeTab: 2);
      final (next, _) = m.update(_key('h'));
      expect((next as TabsModel).activeTab, equals(1));
    });

    test('tab wraps to next tab', () {
      final m = TabsModel(tabs: tabs, activeTab: 1);
      final (next, _) = m.update(_namedKey('tab'));
      expect((next as TabsModel).activeTab, equals(2));
    });

    test('tab wraps around from last to first', () {
      final m = TabsModel(tabs: tabs, activeTab: 2);
      final (next, _) = m.update(_namedKey('tab'));
      expect((next as TabsModel).activeTab, equals(0));
    });
  });

  group('TabsModel view', () {
    test('tabBar contains all tab labels', () {
      final m = TabsModel(tabs: tabs);
      final bar = m.tabBar();
      for (final (label, _) in tabs) {
        expect(stripAnsi(bar), contains(label));
      }
    });

    test('activeContent returns content for active tab', () {
      final m = TabsModel(tabs: tabs, activeTab: 1);
      expect(m.activeContent(), equals('Profile content'));
    });

    test('view contains active content', () {
      final m = TabsModel(tabs: tabs, activeTab: 0);
      expect(m.view().content, contains('Home content'));
    });

    test('view contains tab divider', () {
      final m = TabsModel(tabs: tabs);
      expect(stripAnsi(m.view().content), contains('│'));
    });
  });

  group('TabsModel assertions', () {
    test('empty tabs list throws assertion', () {
      expect(() => TabsModel(tabs: const []), throwsA(isA<AssertionError>()));
    });
  });
}
