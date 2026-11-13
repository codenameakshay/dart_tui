import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';
import 'package:dart_tui/testing.dart' show CaptureSink;

void main() {
  test('AnsiRenderer wraps frame with sync markers when syncUpdates enabled',
      () {
    final buf = StringBuffer();
    final sink = CaptureSink(buf);
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
    final sink = CaptureSink(buf);
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
