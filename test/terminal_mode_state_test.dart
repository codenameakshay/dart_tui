import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/terminal_mode_state.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

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
      expect(state.apply(_StringSink(buffer), newView('value')), isFalse);
      expect(buffer.toString(), equals('\x1b[?25l\x1b[?2004h'));

      buffer.clear();
      expect(state.apply(_StringSink(buffer), newView('value')), isFalse);
      expect(buffer.toString(), isEmpty);
    });

    test('startup focus and mouse defaults outrank an empty view', () {
      state = TerminalModeState(
        defaultAltScreen: false,
        defaultHideCursor: false,
        defaultMouseMode: MouseMode.cellMotion,
        defaultReportFocus: true,
      );

      state.apply(_StringSink(buffer), newView('value'));

      expect(buffer.toString(), contains('\x1b[?1004h'));
      expect(
        buffer.toString(),
        contains('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l'),
      );
      expect(buffer.toString(), contains('\x1b[?1002h\x1b[?1006h'));
    });

    test('reports alternate-screen changes for cache invalidation', () {
      final sink = _StringSink(buffer);

      expect(state.apply(sink, View(content: 'x', altScreen: true)), isTrue);
      expect(state.altScreenEnabled, isTrue);
      expect(state.apply(sink, View(content: 'x', altScreen: true)), isFalse);
      expect(state.setAltScreen(sink, false), isTrue);
      expect(state.setAltScreen(sink, false), isFalse);
    });

    test('imperative cursor visibility is idempotent', () {
      final sink = _StringSink(buffer);

      expect(state.setCursorVisibility(sink, false), isTrue);
      expect(state.setCursorVisibility(sink, false), isFalse);
      expect(state.setCursorVisibility(sink, true), isTrue);
      expect(buffer.toString(), equals('\x1b[?25l\x1b[?25h'));
    });

    test('reset emits one complete terminal-mode teardown', () {
      final sink = _StringSink(buffer);
      state.apply(
        sink,
        View(
          content: 'x',
          altScreen: true,
          reportFocus: true,
          mouseMode: MouseMode.allMotion,
        ),
      );
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

    test('reset omits alt-screen exit when alt screen was never enabled (#18)',
        () {
      final sink = _StringSink(buffer);
      state.apply(sink, newView('value'));
      buffer.clear();

      state.reset(sink);

      expect(buffer.toString(), isNot(contains('\x1b[?1049l')));
      expect(state.altScreenEnabled, isFalse);
    });
  });
}

final class _StringSink implements IOSink {
  _StringSink(this.buffer);

  final StringBuffer buffer;

  @override
  Encoding encoding = utf8;
  @override
  void add(List<int> data) => buffer.write(encoding.decode(data));
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? object) => buffer.write(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
}
