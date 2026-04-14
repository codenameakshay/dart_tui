import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

class _TestKeyMap implements KeyMap {
  _TestKeyMap(this.bindings);
  @override
  final List<KeyBinding> bindings;
}

void main() {
  group('HelpModel', () {
    final entries = [
      (key: '↑/↓', description: 'Navigate'),
      (key: 'Enter', description: 'Select'),
      (key: 'q', description: 'Quit'),
    ];

    test('view contains all keys', () {
      final h = HelpModel(entries: entries);
      final content = h.view().content;
      expect(content, contains('↑/↓'));
      expect(content, contains('Enter'));
      expect(content, contains('q'));
    });

    test('view contains all descriptions', () {
      final h = HelpModel(entries: entries);
      final content = h.view().content;
      expect(content, contains('Navigate'));
      expect(content, contains('Select'));
      expect(content, contains('Quit'));
    });

    test('view shows title', () {
      final h = HelpModel(entries: entries, title: 'Keybindings');
      expect(h.view().content, contains('Keybindings'));
    });

    test('showBorder adds border characters', () {
      final h = HelpModel(entries: entries, showBorder: true);
      final content = h.view().content;
      expect(content, contains('┌'));
      expect(content, contains('└'));
    });

    test('no border by default', () {
      final h = HelpModel(entries: entries, showBorder: false);
      final content = h.view().content;
      expect(content, isNot(contains('┌')));
    });

    test('update is a no-op', () {
      final h = HelpModel(entries: entries);
      final (next, cmd) = h.update(TickMsg(DateTime.now()));
      expect(identical(h, next), isTrue);
      expect(cmd, isNull);
    });

    test('fromKeyMap factory creates entries from enabled bindings only', () {
      final map = _TestKeyMap([
        KeyBinding(keys: ['q'], help: (key: 'q', description: 'Quit')),
        KeyBinding(
          keys: ['?'],
          help: (key: '?', description: 'Help'),
          enabled: false,
        ),
      ]);
      final h = HelpModel.fromKeyMap(map);
      final content = h.view().content;
      expect(content, contains('Quit'));
      // The '?' key (disabled binding) should not appear
      expect(content, isNot(contains('?')));
    });
  });
}
