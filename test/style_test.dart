import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('style applies ansi foreground and bold', () {
    final out = const Style().foregroundColor256(39).bold().render('hello');
    expect(out, contains('\x1b[1m'));
    expect(out, contains('\x1b[38;5;39m'));
    expect(out, contains('hello'));
    expect(out, endsWith(TuiStyle.reset));
  });

  test('style applies padding and border', () {
    final out = const Style()
        .withPadding(const EdgeInsets.all(1))
        .withBorder(Border.rounded)
        .render('x');
    expect(out, contains('╭'));
    expect(out, contains('╯'));
    expect(out, contains('x'));
  });

  test('legacy TuiStyle helpers still work', () {
    final wrapped = TuiStyle.wrap('x', open: TuiStyle.fg256(208));
    expect(wrapped, contains('\x1b[38;5;208m'));
    expect(wrapped, endsWith(TuiStyle.reset));
  });
}
