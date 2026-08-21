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
  test('AnsiRenderer clears unknown initial row content before writing', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );

    renderer.render(newView('short'));

    expect(buf.toString(), contains('\x1b[1;1H\x1b[Kshort'));
  });

  test('AnsiRenderer strips controls from window titles', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: true,
    );

    renderer.render(View(
      content: 'value',
      windowTitle: 'safe\x07\x1b]2;owned\x07\x9c\x7fevil',
    ));

    expect(buf.toString(), contains('\x1b]0;safe]2;ownedevil\x07'));
    expect(buf.toString(), isNot(contains('\x1b]2;owned')));
  });

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

  test('AnsiRenderer applies and resets terminal colors and progress', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    final active = View(
      content: 'value',
      foregroundColor: 0x123456,
      backgroundColor: 0xabcdef,
      progressBar: const ProgressBar(
        state: ProgressBarState.normal,
        value: 150,
      ),
    );

    renderer.render(active);

    expect(buf.toString(), contains('\x1b]10;#123456\x07'));
    expect(buf.toString(), contains('\x1b]11;#abcdef\x07'));
    expect(buf.toString(), contains('\x1b]9;4;1;100\x07'));

    buf.clear();
    renderer.render(active);
    expect(buf.toString(), isEmpty);

    renderer.render(newView('value'));
    expect(
      buf.toString(),
      equals('\x1b]110\x07\x1b]111\x07\x1b]9;4;0\x07'),
    );
  });

  test('AnsiRenderer release resets active terminal colors and progress', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.render(View(
      content: 'value',
      foregroundColor: 0x123456,
      backgroundColor: 0xabcdef,
      progressBar: const ProgressBar(
        state: ProgressBarState.indeterminate,
        value: 0,
      ),
    ));
    buf.clear();

    renderer.release();

    final output = buf.toString();
    expect(output, startsWith('\x1b]110\x07\x1b]111\x07\x1b]9;4;0\x07'));
  });

  test('AnsiRenderer negotiates and resets keyboard enhancements', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    final enhanced = View(
      content: 'value',
      keyboardEnhancements: const KeyboardEnhancements(
        reportEventTypes: true,
        reportAlternateKeys: true,
        reportAllKeysAsEscapeCodes: true,
        reportAssociatedText: true,
      ),
    );

    renderer.render(enhanced);

    expect(buf.toString(), contains('\x1b[>4;2m\x1b[=31;1u\x1b[?u'));

    buf.clear();
    renderer.render(enhanced);
    expect(buf.toString(), isEmpty);

    renderer.render(View(
      content: 'value',
      keyboardEnhancements: const KeyboardEnhancements(
        reportEventTypes: true,
      ),
    ));
    expect(buf.toString(), equals('\x1b[>4;2m\x1b[=3;1u\x1b[?u'));

    buf.clear();
    renderer.release();
    expect(buf.toString(), startsWith('\x1b[>4m\x1b[=0;1u'));
  });

  test('AnsiRenderer resets keyboard state before changing screen registry',
      () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    const keyboard = KeyboardEnhancements(reportEventTypes: true);
    renderer.render(View(
      content: 'value',
      keyboardEnhancements: keyboard,
    ));
    buf.clear();

    renderer.render(View(
      content: 'value',
      altScreen: true,
      keyboardEnhancements: keyboard,
    ));

    expect(
      buf.toString(),
      startsWith(
        '\x1b[>4m\x1b[=0;1u'
        '\x1b[?1049h'
        '\x1b[>4;2m\x1b[=3;1u\x1b[?u',
      ),
    );
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

  test('AnsiRenderer repaints unchanged content after a screen change', () {
    final buf = StringBuffer();
    final renderer = AnsiRenderer(
      output: _StringSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.render(newView('same'));
    buf.clear();

    renderer.render(View(content: 'same', altScreen: true));

    expect(buf.toString(), contains('\x1b[?1049h'));
    expect(buf.toString(), contains('\x1b[1;1H\x1b[Ksame'));
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

  group('scrollback preservation (#18)', () {
    test('close parks the cursor below the last painted row', () {
      final buf = StringBuffer();
      final renderer = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );

      renderer.render(newView('line1\nline2'));
      buf.clear();

      renderer.close();

      expect(buf.toString(), endsWith('\x1b[3;1H'));
    });

    test('parking follows the bottom of the view as it grows', () {
      final buf = StringBuffer();
      final renderer = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );

      renderer.render(newView('one'));
      renderer.render(newView('one\ntwo\nthree'));
      buf.clear();

      renderer.close();

      expect(buf.toString(), endsWith('\x1b[4;1H'));
    });

    test('release(reset: true) does not park the cursor', () {
      final buf = StringBuffer();
      final renderer = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );

      renderer.render(newView('line1\nline2'));
      buf.clear();

      renderer.release(reset: true);

      expect(buf.toString(), isNot(contains(';3;1H')));
      expect(buf.toString(), contains('\x1b[2J'));
    });

    test('close skips cursor parking in the alternate screen', () {
      final buf = StringBuffer();
      final renderer = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );

      renderer.render(View(content: 'alt\nscreen', altScreen: true));
      buf.clear();

      renderer.close();

      final output = buf.toString();
      expect(output, contains('\x1b[?1049l'));
      expect(output, isNot(contains(';1H')));
    });
  });
}
