import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:test/test.dart';

class _Sink implements IOSink {
  final StringBuffer buf = StringBuffer();
  @override
  void write(Object? o) => buf.write(o);
  @override
  void writeln([Object? o = '']) => buf.writeln(o);
  @override
  void writeAll(Iterable objs, [String sep = '']) => buf.writeAll(objs, sep);
  @override
  void writeCharCode(int c) => buf.writeCharCode(c);
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  void add(List<int> d) => buf.write(utf8.decode(d));
  @override
  void addError(Object e, [StackTrace? st]) {}
  @override
  Future<void> addStream(Stream<List<int>> s) async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding v) {}
}

void _driveModes(TeaRenderer r, _Sink sink) {
  // Flip every mode on...
  r.render(View(
    content: 'x',
    mouseMode: MouseMode.cellMotion,
    reportFocus: true,
    altScreen: true,
    windowTitle: 'Title',
    cursor: const Cursor(x: 1, y: 1),
  ));
  r.render(View(content: 'y', mouseMode: MouseMode.allMotion));
  // ...and back off.
  r.render(View(content: 'z', disableBracketedPasteMode: true));
  // imperative toggles
  r.setAltScreen(true);
  r.setAltScreen(false);
  r.setCursorVisibility(false);
  r.setCursorVisibility(true);
  r.scroll(2, up: true);
  r.scroll(1, up: false);
  r.scroll(0); // no-op guard
  r.clearScreen();
  r.insertAbove('above (primary)');
  r.setAltScreen(true);
  r.insertAbove('above (alt)');
  r.render(View(content: 'after'));
  r.restore(View(content: 'restored'));
  r.release(reset: true);
  r.close();
}

void main() {
  test('AnsiRenderer drives all modes, sync updates, scroll, insertAbove', () {
    final sink = _Sink();
    final r = AnsiRenderer(
        output: sink, defaultAltScreen: false, defaultHideCursor: true);
    r.setSyncUpdates(true);
    r.render(View(content: 'a\nb'));
    r.render(View(content: 'a\nB')); // changed → sync-wrapped diff
    expect(sink.buf.toString(), contains('\x1b[?2026h'));
    _driveModes(r, sink);
    expect(sink.buf.toString(), contains('\x1b]0;Title\x07'));
    expect(sink.buf.toString(), contains('\x1b[2S')); // scroll up 2
  });

  test('CellRenderer drives modes + grid escape parsing (SGR/OSC/wide/lone)',
      () {
    final sink = _Sink();
    final r = CellRenderer(
        output: sink, defaultAltScreen: false, defaultHideCursor: true);
    // content mixing SGR, an OSC sequence, a wide char, and a lone escape
    r.render(View(content: '\x1b[1;32mgreen\x1b[0m 你 \x1b]0;t\x07\x1b7end'));
    r.render(View(content: '\x1b[31mred\x1b[0m 世'));
    _driveModes(r, sink);
    expect(sink.buf.toString(), isNotEmpty);
  });

  test('NilRenderer is a total no-op across the interface', () {
    final r = NilRenderer();
    r.render(View(content: 'x'));
    r.clearScreen();
    r.insertAbove('l');
    r.setSyncUpdates(true);
    r.setAltScreen(true);
    r.setCursorVisibility(false);
    r.scroll(1);
    r.restore(View(content: 'x'));
    r.release(reset: true);
    r.close();
    // no throw == success
    expect(true, isTrue);
  });
}
