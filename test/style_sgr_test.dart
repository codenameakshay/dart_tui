// Tests for new SGR attributes: reverse, blink, overline, and related flags.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

const _sgrReset = '\x1b[0m';

void main() {
  group('rich underline styles', () {
    const expected = {
      UnderlineStyle.single: '\x1b[4m',
      UnderlineStyle.double: '\x1b[4:2m',
      UnderlineStyle.curly: '\x1b[4:3m',
      UnderlineStyle.dotted: '\x1b[4:4m',
      UnderlineStyle.dashed: '\x1b[4:5m',
    };

    for (final entry in expected.entries) {
      test('${entry.key.name} emits its SGR underline form', () {
        final out = const Style().withUnderlineStyle(entry.key).render('text');
        expect(out, contains(entry.value));
      });
    }

    test('none explicitly disables an inherited underline', () {
      final style = const Style(underlineStyle: UnderlineStyle.none)
          .inherit(const Style(underlineStyle: UnderlineStyle.curly));
      expect(style.render('text'), isNot(contains('\x1b[4')));
    });

    test('underline color emits RGB state and an explicit reset', () {
      final out = const Style(
        underlineStyle: UnderlineStyle.curly,
        underlineColor: RgbColor(12, 34, 56),
      ).render('text');
      expect(out, contains('\x1b[58;2;12;34;56m'));
      expect(out, contains('\x1b[59m'));
    });

    test('underline(bool) maps to single and none', () {
      expect(const Style().underline().underlineStyle, UnderlineStyle.single);
      expect(
          const Style().underline(false).underlineStyle, UnderlineStyle.none);
    });
  });

  group('OSC 8 hyperlinks', () {
    test('renders a balanced URL and parameter pair', () {
      final out = const Style(
        hyperlinkUrl: 'https://example.com',
        hyperlinkParams: 'id=docs',
      ).render('docs');
      expect(out, startsWith('\x1b]8;id=docs;https://example.com\x1b\\'));
      expect(out, endsWith('\x1b]8;;\x1b\\'));
      expect(stripAnsi(out), 'docs');
    });

    test('removes terminal controls from URL and parameters', () {
      final out = const Style()
          .withHyperlink(
            'https://safe.example/\x1b]8;;evil\x07\u009bpath',
            params: 'id=x\x1b\\\nnext\u007f',
          )
          .render('safe');
      expect(out, isNot(contains('evil\x07')));
      expect(out, isNot(contains('\u009b')));
      expect(out, isNot(contains('\n')));
      expect(out, contains('https://safe.example/]8;;evilpath'));
      expect(out, contains('id=xnext'));
    });

    test('empty URL does not emit OSC 8', () {
      expect(const Style(hyperlinkUrl: '').render('plain'), 'plain');
    });
  });

  group('SGR reverse (SGR 7)', () {
    test('isReverse emits \\x1b[7m', () {
      final out = const Style().reverse().render('text');
      expect(out, contains('\x1b[7m'));
      expect(out, contains('text'));
      expect(out, endsWith(_sgrReset));
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
      final parent = const Style(foregroundRgb: RgbColor(203, 166, 247));
      final child = const Style().inherit(parent);
      final out = child.render('hi');
      expect(out, contains('\x1b[38;2;203;166;247m'));
    });

    test('child with own color does not adopt parent color', () {
      final parent = const Style(foregroundRgb: RgbColor(255, 0, 0));
      final child =
          const Style(foregroundRgb: RgbColor(0, 255, 0)).inherit(parent);
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

    test('underline with underlineSpaces=true (default) wraps whole string',
        () {
      final out = const Style(isUnderline: true).render('hello world');
      // Standard: single open sequence, single close
      expect(out, startsWith('\x1b[4m'));
      expect(out, endsWith(_sgrReset));
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
