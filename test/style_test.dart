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

  group('Style width/height constraints', () {
    test('width pads short lines', () {
      final s = const Style().withWidth(10);
      final rendered = s.render('hi');
      // Strip ANSI and check padded
      final plain = rendered.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      expect(plain.length, greaterThanOrEqualTo(10));
    });

    test('maxWidth truncates long lines', () {
      final s = const Style().withMaxWidth(5);
      final rendered = s.render('hello world');
      final plain = rendered.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      expect(plain.length, lessThanOrEqualTo(5));
    });

    test('height pads with blank lines', () {
      final s = const Style().withHeight(5);
      final rendered = s.render('line1\nline2');
      expect(rendered.split('\n').length, 5);
    });
  });

  group('Style alignment', () {
    test('center alignment pads both sides', () {
      final s = const Style().withWidth(10).withAlign(Align.center);
      final rendered = s.render('hi');
      final plain = rendered.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      // Should be padded on both sides
      expect(plain.startsWith(' '), isTrue);
      expect(plain.endsWith(' '), isTrue);
    });

    test('right alignment pads left', () {
      final s = const Style().withWidth(10).withAlign(Align.right);
      final rendered = s.render('hi');
      final plain = rendered.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      expect(plain.startsWith(' '), isTrue);
    });
  });

  group('Style inline mode', () {
    test('inline collapses newlines', () {
      final s = const Style().withInline(true);
      final rendered = s.render('hello\nworld');
      expect(rendered, isNot(contains('\n')));
    });
  });

  group('Style color profile', () {
    test('noColor profile emits no ANSI color codes', () {
      final s = const Style(
        foreground256: 196,
        profile: ColorProfile.noColor,
      );
      final rendered = s.render('red text');
      expect(rendered, isNot(contains('\x1b[')));
    });

    test('ansi profile degrades RGB to ansi16', () {
      final s = Style(
        foregroundRgb: const RgbColor(255, 0, 0),
        profile: ColorProfile.ansi,
      );
      final rendered = s.render('text');
      // Should contain a \x1b[3Xm style ANSI 16 code (30–37)
      expect(rendered, matches(RegExp(r'\x1b\[3[0-7]m')));
    });
  });
}
