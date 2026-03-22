import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

void main() {
  test('AnsiRenderer wraps frame with sync markers when syncUpdates enabled',
      () {
    final buf = StringBuffer();
    final sink = _StringSink(buf);
    final renderer = AnsiRenderer(
      output: sink,
      logSink: null,
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.setSyncUpdates(true);
    renderer.render(newView('hello'));
    final output = buf.toString();
    expect(output, contains('\x1b[?2026h'));
    expect(output, contains('\x1b[?2026l'));
    // Sync start must come before sync end
    expect(
        output.indexOf('\x1b[?2026h'), lessThan(output.indexOf('\x1b[?2026l')));
  });

  test('AnsiRenderer does NOT wrap frame when syncUpdates disabled', () {
    final buf = StringBuffer();
    final sink = _StringSink(buf);
    final renderer = AnsiRenderer(
      output: sink,
      logSink: null,
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.render(newView('hello'));
    final output = buf.toString();
    expect(output, isNot(contains('\x1b[?2026h')));
    expect(output, isNot(contains('\x1b[?2026l')));
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
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
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
