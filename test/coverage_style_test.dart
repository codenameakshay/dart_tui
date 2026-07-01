import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('Style rendering', () {
    test('all SGR attributes strip back to the original text', () {
      const s = Style(
        isBold: true,
        isDim: true,
        isItalic: true,
        isUnderline: true,
        isStrikethrough: true,
        isReverse: true,
        isBlink: true,
        isOverline: true,
      );
      expect(stripAnsi(s.render('hi')), 'hi');
      expect(s.render('hi'), contains('\x1b['));
    });

    test('256 and rgb colors render escape codes', () {
      expect(const Style(foreground256: 42, background256: 7).render('x'),
          contains('\x1b['));
      expect(
          const Style(
                  foregroundRgb: RgbColor(1, 2, 3),
                  backgroundRgb: RgbColor(4, 5, 6))
              .render('x'),
          contains('38;2;1;2;3'));
    });

    test('color profile degradation', () {
      const c = RgbColor(200, 100, 50);
      for (final p in ColorProfile.values) {
        final out = Style(foregroundRgb: c, profile: p).render('x');
        expect(stripAnsi(out), 'x');
      }
      // noColor yields no escapes at all
      expect(
          const Style(foregroundRgb: c, profile: ColorProfile.noColor)
              .render('x'),
          'x');
    });

    test('CompleteColor picks per-profile value; AdaptiveColor renders', () {
      const cc =
          CompleteColor(trueColor: RgbColor(1, 2, 3), ansi256: 5, ansi: 1);
      for (final p in ColorProfile.values) {
        expect(stripAnsi(Style(foregroundComplete: cc, profile: p).render('x')),
            'x');
      }
      const ac = AdaptiveColor(
          light: RgbColor(0, 0, 0), dark: RgbColor(255, 255, 255));
      expect(
          stripAnsi(const Style(adaptiveForeground: ac, adaptiveBackground: ac)
              .render('x')),
          'x');
    });

    test('layout: padding, margin, border+title, width/align, wordwrap, tabs',
        () {
      final s = const Style(
        padding: EdgeInsets.all(1),
        margin: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
        marginBackground: RgbColor(10, 10, 10),
        border: Border.rounded,
        borderForeground: RgbColor(1, 1, 1),
        borderTitle: 'Title',
        borderTitleAlignment: Align.center,
        width: 20,
        height: 4,
        align: Align.center,
        alignVertical: AlignVertical.middle,
        wordWrap: true,
        tabWidth: 2,
      );
      final out = s.render('a\tb hello world this wraps');
      expect(out, isNotEmpty);
      expect(getHeight(out), greaterThan(1));
    });

    test('transform hook and inline mode', () {
      expect(
          Style(transform: (s) => s.toUpperCase(), inline: true).render('ab'),
          contains('AB'));
    });

    test('inherit fills unset fields from a parent', () {
      const parent = Style(isBold: true, foreground256: 3);
      const child = Style(isItalic: true);
      final merged = child.inherit(parent);
      expect(merged.isBold, isTrue);
      expect(merged.isItalic, isTrue);
    });
  });

  group('Border presets and per-side control', () {
    test('every preset renders', () {
      for (final b in [
        Border.none,
        Border.rounded,
        Border.box,
        Border.thick,
        Border.double,
        Border.hidden,
        Border.normal,
      ]) {
        expect(Style(border: b).render('x'), isNotEmpty);
      }
    });

    test('per-side helpers and copyWith', () {
      expect(Style(border: Border.rounded.topOnly).render('x'), isNotEmpty);
      expect(Style(border: Border.rounded.bottomOnly).render('x'), isNotEmpty);
      expect(Style(border: Border.rounded.sidesOnly).render('x'), isNotEmpty);
      final custom = Border.box.copyWith(showLeft: false);
      expect(custom.showLeft, isFalse);
    });
  });

  group('EdgeInsets constructors', () {
    test('all / symmetric / only', () {
      expect(const EdgeInsets.all(2).top, 2);
      expect(const EdgeInsets.symmetric(vertical: 1, horizontal: 3).left, 3);
      expect(const EdgeInsets(top: 1, right: 2, bottom: 3, left: 4).bottom, 3);
    });
  });

  group('layout + width helpers', () {
    test('join and place compose blocks', () {
      expect(joinVertical(Align.center, ['a', 'bbb']), contains('a'));
      expect(joinHorizontal(AlignVertical.middle, ['a\nb', 'c']), isNotEmpty);
      expect(
          getHeight(place(10, 3, Align.center, AlignVertical.middle, 'x')), 3);
      expect(placeHorizontal(6, Align.right, 'x'), endsWith('x'));
      expect(getHeight(placeVertical(4, AlignVertical.bottom, 'x')), 4);
    });

    test('getHeight, truncate, truncateLeft', () {
      expect(getHeight('a\nb\nc'), 3);
      expect(getHeight(''), 1);
      expect(truncate('short', 20), 'short');
      expect(truncateLeft('short', 20), 'short');
    });

    test('gradients render one escape run per character', () {
      const colors = [RgbColor(255, 0, 0), RgbColor(0, 0, 255)];
      expect(stripAnsi(gradientText('hello', colors)), 'hello');
      expect(stripAnsi(gradientBackground('hi', colors)), 'hi');
    });
  });

  group('TuiStyle escape helpers', () {
    test('static SGR builders', () {
      expect(TuiStyle.fg256(5), '\x1b[38;5;5m');
      expect(TuiStyle.bg256(5), '\x1b[48;5;5m');
      expect(TuiStyle.fgRgb(1, 2, 3), '\x1b[38;2;1;2;3m');
      expect(TuiStyle.bgRgb(1, 2, 3), '\x1b[48;2;1;2;3m');
      expect(TuiStyle.wrap('x', open: TuiStyle.bold), contains('x'));
    });
  });
}
