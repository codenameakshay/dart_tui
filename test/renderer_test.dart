import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

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

void main() {
  test('renderer skips identical frame content', () async {
    final chunks = <String>[];
    final controller = StreamController<List<int>>();
    controller.stream.listen((data) => chunks.add(utf8.decode(data)));
    final sink = IOSink(controller.sink);

    final r = AnsiRenderer(
      output: sink,
      defaultAltScreen: false,
      defaultHideCursor: true,
    );

    r.render(newView('hello'));
    await sink.flush();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final first = chunks.join();
    expect(first, contains('hello'));

    chunks.clear();
    r.render(newView('hello'));
    await sink.flush();
    expect(chunks.join(), isEmpty);

    r.close();
    await sink.close();
    await controller.close();
  });

  group('insertAbove in alt-screen mode', () {
    test('emits save-cursor, scroll-up, and restore-cursor escape sequences',
        () {
      final buf = StringBuffer();
      final sink = _StringSink(buf);
      final renderer = AnsiRenderer(
        output: sink,
        logSink: null,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      // Enable alt screen by rendering a view with altScreen: true
      renderer.render(View(content: 'initial', altScreen: true));
      buf.clear();
      renderer.insertAbove('test line');
      final output = buf.toString();
      expect(output, contains('\x1b[s')); // save cursor
      expect(output, contains('\x1b[S')); // scroll up
      expect(output, contains('\x1b[u')); // restore cursor
    });
  });
}
