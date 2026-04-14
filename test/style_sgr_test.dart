// Tests for new SGR attributes: reverse, blink, overline, and related flags.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('SGR reverse (SGR 7)', () {
    test('isReverse emits \\x1b[7m', () {
      final out = const Style().reverse().render('text');
      expect(out, contains('\x1b[7m'));
      expect(out, contains('text'));
      expect(out, endsWith(TuiStyle.reset));
    });

    test('reverse(false) does not emit \\x1b[7m', () {
      final out = const Style().reverse(false).render('text');
      expect(out, isNot(contains('\x1b[7m')));
    });

    test('isReverse null default does not emit \\x1b[7m', () {
      final out = const Style().render('text');
      expect(out, isNot(contains('\x1b[7m')));
    });
  });

  group('SGR blink (SGR 5)', () {
    test('isBlink emits \\x1b[5m', () {
      final out = const Style().blink().render('blink');
      expect(out, contains('\x1b[5m'));
      expect(out, contains('blink'));
    });

    test('blink(false) does not emit \\x1b[5m', () {
      final out = const Style().blink(false).render('text');
      expect(out, isNot(contains('\x1b[5m')));
    });
  });

  group('SGR overline (SGR 53)', () {
    test('isOverline emits \\x1b[53m', () {
      final out = const Style().overline().render('over');
      expect(out, contains('\x1b[53m'));
    });

    test('overline(false) does not emit \\x1b[53m', () {
      final out = const Style().overline(false).render('text');
      expect(out, isNot(contains('\x1b[53m')));
    });
  });

  group('Style.Inherit', () {
    test('child inherits isBold from parent when unset', () {
      final parent = const Style(isBold: true);
      final child = const Style().inherit(parent);
      final out = child.render('hi');
      expect(out, contains('\x1b[1m'));
    });

    test('explicitly false child does not inherit parent true', () {
      final parent = const Style(isBold: true);
      final child = const Style(isBold: false).inherit(parent);
      // isBold is explicitly false — the explicit value wins
      // Note: false is the same as null for rendering (both → not bold)
      // but inherit() distinguishes: false stays false, null is replaced
      final out = child.render('hi');
      // false → not bold → no bold sequence
      expect(out, isNot(contains('\x1b[1m')));
    });

    test('child inherits foregroundRgb from parent', () {
      final parent =
          const Style(foregroundRgb: RgbColor(203, 166, 247));
      final child = const Style().inherit(parent);
      final out = child.render('hi');
      expect(out, contains('\x1b[38;2;203;166;247m'));
    });

    test('child with own color does not adopt parent color', () {
      final parent =
          const Style(foregroundRgb: RgbColor(255, 0, 0));
      final child = const Style(foregroundRgb: RgbColor(0, 255, 0)).inherit(parent);
      final out = child.render('hi');
      expect(out, contains('\x1b[38;2;0;255;0m'));
      expect(out, isNot(contains('\x1b[38;2;255;0;0m')));
    });

    test('child inherits isItalic from parent', () {
      final parent = const Style(isItalic: true);
      final child = const Style().inherit(parent);
      expect(child.render('x'), contains('\x1b[3m'));
    });

    test('unsetBold removes explicit value and allows inheritance', () {
      const s = Style(isBold: true);
      final unset = s.unsetBold();
      expect(unset.isBold, isNull);
    });
  });

  group('underlineSpaces / strikethroughSpaces', () {
    test('underline with underlineSpaces=false wraps each word', () {
      final out = const Style(isUnderline: true, underlineSpaces: false)
          .render('hello world');
      // Should re-apply SGR codes around each word
      expect(out.split('\x1b[0m').length, greaterThan(2));
    });

    test('underline with underlineSpaces=true (default) wraps whole string', () {
      final out = const Style(isUnderline: true).render('hello world');
      // Standard: single open sequence, single close
      expect(out, startsWith('\x1b[4m'));
      expect(out, endsWith(TuiStyle.reset));
    });
  });

  group('Style.transform', () {
    test('transform function is applied to rendered output', () {
      final out = Style(transform: (s) => s.toUpperCase()).render('hello');
      expect(out, equals('HELLO'));
    });

    test('transform receives ANSI-wrapped string', () {
      String? received;
      const Style(isBold: true).copyWith(
        transform: (s) {
          received = s;
          return s;
        },
      ).render('x');
      expect(received, contains('\x1b[1m'));
    });
  });

  group('CompleteColor', () {
    test('trueColor profile uses trueColor from CompleteColor', () {
      final out = const Style(
        foregroundComplete: CompleteColor(
          trueColor: RgbColor(100, 200, 50),
          ansi256: 42,
          ansi: 2,
        ),
        profile: ColorProfile.trueColor,
      ).render('x');
      expect(out, contains('\x1b[38;2;100;200;50m'));
    });

    test('ansi256 profile uses ansi256 from CompleteColor', () {
      final out = const Style(
        foregroundComplete: CompleteColor(
          trueColor: RgbColor(100, 200, 50),
          ansi256: 42,
          ansi: 2,
        ),
        profile: ColorProfile.ansi256,
      ).render('x');
      expect(out, contains('\x1b[38;5;42m'));
    });

    test('ansi profile uses ansi16 from CompleteColor', () {
      final out = const Style(
        foregroundComplete: CompleteColor(
          trueColor: RgbColor(100, 200, 50),
          ansi256: 42,
          ansi: 2,
        ),
        profile: ColorProfile.ansi,
      ).render('x');
      // ansi16 index 2 = green (32m)
      expect(out, matches(RegExp(r'\x1b\[3[0-7]m')));
    });

    test('noColor profile emits no color codes even with CompleteColor', () {
      final out = const Style(
        foregroundComplete: CompleteColor(
          trueColor: RgbColor(100, 200, 50),
          ansi256: 42,
          ansi: 2,
        ),
        profile: ColorProfile.noColor,
      ).render('x');
      expect(out, equals('x'));
    });
  });
}
