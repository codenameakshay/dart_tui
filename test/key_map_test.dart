import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a single printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  group('KeyBinding', () {
    test('matches when key in list and enabled', () {
      const binding = KeyBinding(
        keys: ['q', 'ctrl+c'],
        help: (key: 'q', description: 'quit'),
      );
      final msg = _char('q');
      expect(binding.matches(msg), isTrue);
    });

    test('does not match when key not in list', () {
      const binding = KeyBinding(
        keys: ['q'],
        help: (key: 'q', description: 'quit'),
      );
      final msg = _char('x');
      expect(binding.matches(msg), isFalse);
    });

    test('does not match when disabled', () {
      const binding = KeyBinding(
        keys: ['q'],
        help: (key: 'q', description: 'quit'),
        enabled: false,
      );
      final msg = _char('q');
      expect(binding.matches(msg), isFalse);
    });

    test('withEnabled returns new binding with changed enabled', () {
      const binding = KeyBinding(
        keys: ['q'],
        help: (key: 'q', description: 'quit'),
        enabled: true,
      );
      final disabled = binding.withEnabled(false);
      expect(disabled.enabled, isFalse);
      expect(disabled.keys, binding.keys);
    });
  });

  group('HelpModel.fromKeyMap', () {
    test('creates entries from enabled bindings only', () {
      final map = _TestKeyMap();
      final help = HelpModel.fromKeyMap(map);
      // Only enabled bindings
      expect(help.entries.length, 2);
      expect(help.entries.first.key, 'q');
      expect(help.entries.last.key, '↑/↓');
    });
  });
}

class _TestKeyMap implements KeyMap {
  @override
  List<KeyBinding> get bindings => [
        const KeyBinding(
          keys: ['q'],
          help: (key: 'q', description: 'quit'),
        ),
        const KeyBinding(
          keys: ['up', 'down'],
          help: (key: '↑/↓', description: 'navigate'),
        ),
        const KeyBinding(
          keys: ['x'],
          help: (key: 'x', description: 'disabled'),
          enabled: false,
        ),
      ];
}
