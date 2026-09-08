import 'package:dart_tui/src/ansi_state.dart';
import 'package:dart_tui/src/bubbles/style.dart';
import 'package:test/test.dart';

void main() {
  group('ANSI width preserves grapheme semantics', () {
    test('ANSI between code points still joins ZWJ and regional pairs', () {
      expect(getWidth('👩\x1b[31m\u200d💻'), 2);
      expect(getWidth('🇮\x1b[31m🇳'), 2);
    });

    test('mixed controls and Unicode retain visible width', () {
      const value =
          '\x1b[1mA❤️\x1b[0m界\x1b]8;;https://example.com\x1b\\e\x1b]8;;\x1b\\';
      expect(stripAnsi(value), 'A❤️界e');
      expect(getWidth(value), 6);
    });
  });

  group('ANSI malformed input', () {
    test('trailing and unterminated escapes remain printable input', () {
      expect(stripAnsi('before\x1b'), 'before\x1b');
      expect(stripAnsi('before\x1b[31'), 'before\x1b[31');
      expect(stripAnsi('before\x1b]8;;url'), 'before\x1b]8;;url');
    });

    test('complete controls are removed without touching adjacent text', () {
      expect(stripAnsi('a\x1b[31mb\x1b[0mc'), 'abc');
      expect(stripAnsi('a\x1b]8;;url\x1b\\b\x1b]8;;\x1b\\c'), 'abc');
    });
  });

  test('SGR state cache invalidates on append and reset', () {
    final state = AnsiStateTracker();
    expect(state.sgrOpenSequence, isEmpty);

    state.accept('\x1b[31m');
    expect(state.sgrOpenSequence, '\x1b[31m');
    state.accept('\x1b[1m');
    expect(state.sgrOpenSequence, '\x1b[31m\x1b[1m');
    state.accept('\x1b[0m');
    expect(state.sgrOpenSequence, isEmpty);
    expect(state.closeSequence, isEmpty);

    state.accept('\x1b[0;32m');
    expect(state.sgrOpenSequence, '\x1b[0;32m');
    expect(state.closeSequence, '\x1b[0m');
  });
}
