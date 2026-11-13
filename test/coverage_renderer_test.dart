import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:test/test.dart';
import 'package:dart_tui/testing.dart' show CaptureSink;

void _driveModes(TeaRenderer r, CaptureSink sink) {
  r.setUnicodeCore(true);
  r.setUnicodeCore(true);
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
  r.setUnicodeCore(true);
  r.close();
}

void main() {
  test('AnsiRenderer drives all modes, sync updates, scroll, insertAbove', () {
    final sink = CaptureSink();
    final r = AnsiRenderer(
        output: sink, defaultAltScreen: false, defaultHideCursor: true);
    r.setSyncUpdates(true);
    r.render(View(content: 'a\nb'));
    r.render(View(content: 'a\nB')); // changed → sync-wrapped diff
    expect(sink.buffer.toString(), contains('\x1b[?2026h'));
    _driveModes(r, sink);
    expect(sink.buffer.toString(), contains('\x1b]0;Title\x07'));
    // Scrolling runs here on the normal screen, where it is a no-op (#18).
    expect(sink.buffer.toString(), isNot(contains('\x1b[2S')));
    expect(sink.buffer.toString(), contains('\x1b[?2027h'));
    expect(sink.buffer.toString(), contains('\x1b[?2027l'));
  });

  test('CellRenderer drives modes + grid escape parsing (SGR/OSC/wide/lone)',
      () {
    final sink = CaptureSink();
    final r = CellRenderer(
        output: sink, defaultAltScreen: false, defaultHideCursor: true);
    // content mixing SGR, an OSC sequence, a wide char, and a lone escape
    r.render(View(content: '\x1b[1;32mgreen\x1b[0m 你 \x1b]0;t\x07\x1b7end'));
    r.render(View(content: '\x1b[31mred\x1b[0m 世'));
    _driveModes(r, sink);
    expect(sink.buffer.toString(), isNotEmpty);
  });

  test('NilRenderer is a total no-op across the interface', () {
    final r = NilRenderer();
    r.render(View(content: 'x'));
    r.clearScreen();
    r.insertAbove('l');
    r.setSyncUpdates(true);
    r.setUnicodeCore(true);
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
