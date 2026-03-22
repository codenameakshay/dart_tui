import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// Internal imports — use package paths to access src directly
import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';

void main() {
  group('CellRenderer', () {
    late StringBuffer buf;
    late _StringSink sink;
    late CellRenderer renderer;

    setUp(() {
      buf = StringBuffer();
      sink = _StringSink(buf);
      renderer = CellRenderer(
        output: sink,
        logSink: null,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
    });

    test('renders first frame with all cells', () {
      renderer.render(newView('ab'));
      final output = buf.toString();
      expect(output, contains('a'));
      expect(output, contains('b'));
    });

    test('second frame with single char change emits only that cell', () {
      renderer.render(newView('hello'));
      buf.clear();
      // Change only the last character
      renderer.render(newView('hellX'));
      final output = buf.toString();
      // Should contain the changed character
      expect(output, contains('X'));
      // Should NOT re-render unchanged 'hell' characters (those positions should not appear)
      // We verify there is exactly one cursor-move sequence (to position of 'o'→'X')
      final cursorMoves = RegExp(r'\x1b\[\d+;\d+H').allMatches(output).length;
      expect(cursorMoves, equals(1));
    });

    test('unchanged frame emits no diff output', () {
      renderer.render(newView('hello'));
      buf.clear();
      renderer.render(newView('hello'));
      final output = buf.toString();
      // No cursor moves or character writes for identical content
      expect(RegExp(r'\x1b\[\d+;\d+H').allMatches(output), isEmpty);
    });

    test('clearScreen resets grid state', () {
      renderer.render(newView('hello'));
      renderer.clearScreen();
      buf.clear();
      renderer.render(newView('hello'));
      final output = buf.toString();
      // After clear, full re-render
      expect(output, contains('hello'));
    });
  });
}

class _StringSink implements IOSink {
  _StringSink(this._buf);
  final StringBuffer _buf;
  @override
  void write(Object? obj) => _buf.write(obj);
  @override
  void writeln([Object? obj = '']) => _buf.writeln(obj);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
}
