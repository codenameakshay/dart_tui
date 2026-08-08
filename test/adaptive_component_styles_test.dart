import 'dart:math' as math;

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('component style palettes', () {
    test('defaults remain the dark-background palettes', () {
      expect(HelpStyles.defaults, same(HelpStyles.forDarkBackground(true)));
      expect(
        FullListStyles.defaults,
        same(FullListStyles.forDarkBackground(true)),
      );
      expect(InputStyles.defaults, same(InputStyles.forDarkBackground(true)));
      expect(
        TextAreaStyles.defaults,
        same(TextAreaStyles.forDarkBackground(true)),
      );
      expect(FormStyles.defaults, same(FormStyles.forDarkBackground(true)));
    });

    test('forBackground delegates to the shared luminance detector', () {
      expect(
        HelpStyles.forBackground(0x000000),
        same(HelpStyles.forDarkBackground(true)),
      );
      expect(
        FullListStyles.forBackground(0xffffff),
        same(FullListStyles.forDarkBackground(false)),
      );
      expect(
        InputStyles.forBackground(0x1e1e2e),
        same(InputStyles.forDarkBackground(isDarkRgb(0x1e1e2e))),
      );
      expect(
        TextAreaStyles.forBackground(0xeff1f5),
        same(TextAreaStyles.forDarkBackground(isDarkRgb(0xeff1f5))),
      );
      expect(
        FormStyles.forBackground(0x808080),
        same(FormStyles.forDarkBackground(isDarkRgb(0x808080))),
      );
    });

    test('primary text remains legible on both terminal backgrounds', () {
      const darkBackground = RgbColor(30, 30, 46);
      const lightBackground = RgbColor(239, 241, 245);

      final pairs = <(RgbColor, RgbColor)>[
        (_foreground(HelpStyles.forDarkBackground(true).title), darkBackground),
        (
          _foreground(HelpStyles.forDarkBackground(false).title),
          lightBackground
        ),
        (
          _foreground(FullListStyles.forDarkBackground(true).normalTitle),
          darkBackground,
        ),
        (
          _foreground(FullListStyles.forDarkBackground(false).normalTitle),
          lightBackground,
        ),
        (_foreground(InputStyles.forDarkBackground(true).text), darkBackground),
        (
          _foreground(InputStyles.forDarkBackground(false).text),
          lightBackground
        ),
        (
          _foreground(TextAreaStyles.forDarkBackground(true).text),
          darkBackground,
        ),
        (
          _foreground(TextAreaStyles.forDarkBackground(false).text),
          lightBackground,
        ),
        (
          _foreground(FormStyles.forDarkBackground(true).option),
          darkBackground
        ),
        (
          _foreground(FormStyles.forDarkBackground(false).option),
          lightBackground
        ),
      ];

      for (final (foreground, background) in pairs) {
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    });

    test('light and dark palettes use distinct foregrounds', () {
      expect(
        HelpStyles.forDarkBackground(true).title.foregroundRgb,
        isNot(HelpStyles.forDarkBackground(false).title.foregroundRgb),
      );
      expect(
        FullListStyles.forDarkBackground(true).normalTitle.foregroundRgb,
        isNot(
            FullListStyles.forDarkBackground(false).normalTitle.foregroundRgb),
      );
      expect(
        InputStyles.forDarkBackground(true).text.foregroundRgb,
        isNot(InputStyles.forDarkBackground(false).text.foregroundRgb),
      );
      expect(
        TextAreaStyles.forDarkBackground(true).text.foregroundRgb,
        isNot(TextAreaStyles.forDarkBackground(false).text.foregroundRgb),
      );
      expect(
        FormStyles.forDarkBackground(true).option.foregroundRgb,
        isNot(FormStyles.forDarkBackground(false).option.foregroundRgb),
      );
    });
  });
}

RgbColor _foreground(Style style) => style.foregroundRgb!;

double _contrast(RgbColor first, RgbColor second) {
  final bright = _luminance(first);
  final dark = _luminance(second);
  final high = bright > dark ? bright : dark;
  final low = bright > dark ? dark : bright;
  return (high + 0.05) / (low + 0.05);
}

double _luminance(RgbColor color) {
  double channel(int value) {
    final normalized = value / 255;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
