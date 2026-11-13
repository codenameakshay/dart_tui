import 'package:dart_tui/src/terminal_mode_state.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';
import 'package:dart_tui/testing.dart' show CaptureSink;

void main() {
  group('TerminalModeState', () {
    late StringBuffer buffer;
    late TerminalModeState state;

    setUp(() {
      buffer = StringBuffer();
      state = TerminalModeState(
        defaultAltScreen: false,
        defaultHideCursor: true,
      );
    });

    test('applies defaults once and then remains idempotent', () {
      expect(state.apply(CaptureSink(buffer), newView('value')), isFalse);
      expect(buffer.toString(), equals('\x1b[?25l\x1b[?2004h'));

      buffer.clear();
      expect(state.apply(CaptureSink(buffer), newView('value')), isFalse);
      expect(buffer.toString(), isEmpty);
    });

    test('startup focus and mouse defaults outrank an empty view', () {
      state = TerminalModeState(
        defaultAltScreen: false,
        defaultHideCursor: false,
        defaultMouseMode: MouseMode.cellMotion,
        defaultReportFocus: true,
      );

      state.apply(CaptureSink(buffer), newView('value'));

      expect(buffer.toString(), contains('\x1b[?1004h'));
      expect(
        buffer.toString(),
        contains('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l'),
      );
      expect(buffer.toString(), contains('\x1b[?1002h\x1b[?1006h'));
    });

    test('reports alternate-screen changes for cache invalidation', () {
      final sink = CaptureSink(buffer);

      expect(state.apply(sink, View(content: 'x', altScreen: true)), isTrue);
      expect(state.altScreenEnabled, isTrue);
      expect(state.apply(sink, View(content: 'x', altScreen: true)), isFalse);
      expect(state.setAltScreen(sink, false), isTrue);
      expect(state.setAltScreen(sink, false), isFalse);
    });

    test('imperative cursor visibility is idempotent', () {
      final sink = CaptureSink(buffer);

      expect(state.setCursorVisibility(sink, false), isTrue);
      expect(state.setCursorVisibility(sink, false), isFalse);
      expect(state.setCursorVisibility(sink, true), isTrue);
      expect(buffer.toString(), equals('\x1b[?25l\x1b[?25h'));
    });

    test('reset emits one complete terminal-mode teardown', () {
      final sink = CaptureSink(buffer);
      state.apply(
        sink,
        View(
          content: 'x',
          altScreen: true,
          reportFocus: true,
          mouseMode: MouseMode.allMotion,
        ),
      );
      expect(buffer.toString(), contains('\x1b[?1049h'));
      buffer.clear();

      state.reset(sink);

      expect(
        buffer.toString(),
        equals(
          '\x1b[?25h'
          '\x1b[?1049l'
          '\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l'
          '\x1b[?1004l'
          '\x1b[?2004l',
        ),
      );
      expect(state.altScreenEnabled, isFalse);
    });

    test('reset skips alt-screen exit when it was never entered', () {
      final sink = CaptureSink(buffer);
      state.apply(sink, newView('value'));
      buffer.clear();

      state.reset(sink);

      final output = buffer.toString();
      expect(output, isNot(contains('\x1b[?1049l')));
      expect(output, contains('\x1b[?25h'));
      expect(
        output,
        contains('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l'),
      );
      expect(output, contains('\x1b[?1004l'));
      expect(output, contains('\x1b[?2004l'));
      expect(state.altScreenEnabled, isFalse);
    });
  });
}
