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
  test('AnsiRenderer applies cursor position, shape, blink, and color', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: true,
    );

    renderer.render(View(
      content: 'value',
      cursor: const Cursor(
        x: 4,
        y: 2,
        color: 0x12abef,
        shape: CursorShape.underline,
        blink: false,
      ),
    ));

    final output = buf.toString();
    expect(output, contains('\x1b[4 q'));
    expect(output, contains('\x1b]12;#12abef\x07'));
    expect(output, endsWith('\x1b[3;5H'));
  });

  test('AnsiRenderer updates cursor state when frame content is unchanged', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: true,
    );
    renderer.render(View(
      content: 'value',
      cursor: const Cursor(
        x: 0,
        y: 0,
        color: 0xffffff,
        shape: CursorShape.underline,
        blink: false,
      ),
    ));
    buf.clear();

    renderer.render(View(
      content: 'value',
      cursor: const Cursor(
        x: 2,
        y: 1,
        shape: CursorShape.bar,
      ),
    ));

    expect(buf.toString(), equals('\x1b[5 q\x1b]112\x07\x1b[2;3H'));
  });

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
