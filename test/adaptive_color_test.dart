// Tests for AdaptiveColor, ColorProfile downgrade, and background detection.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('AdaptiveColor', () {
    test('uses dark variant when background is dark', () {
      final style = const Style(
        adaptiveForeground: AdaptiveColor(
          light: RgbColor(0, 0, 0), // black for light bg
          dark: RgbColor(255, 255, 255), // white for dark bg
        ),
        backgroundRgb: RgbColor(30, 30, 46), // dark
      );
      final out = style.render('x');
      // Should use dark variant: white foreground
      expect(out, contains('\x1b[38;2;255;255;255m'));
    });

    test('uses light variant when background is light', () {
      final style = const Style(
        adaptiveForeground: AdaptiveColor(
          light: RgbColor(0, 0, 0),
          dark: RgbColor(255, 255, 255),
        ),
        backgroundRgb: RgbColor(240, 240, 240), // light
      );
      final out = style.render('x');
      // Should use light variant: black foreground
      expect(out, contains('\x1b[38;2;0;0;0m'));
    });

    test('without explicit background, defaults to dark variant', () {
      // When no background color is set, treats as dark terminal
      final style = const Style(
        adaptiveForeground: AdaptiveColor(
          light: RgbColor(50, 50, 50),
          dark: RgbColor(220, 220, 220),
        ),
      );
      final out = style.render('x');
      expect(out, contains('\x1b[38;2;220;220;220m'));
    });
  });

  group('ColorProfile downgrade', () {
    test('trueColor profile emits RGB codes', () {
      final out = const Style(
        foregroundRgb: RgbColor(203, 166, 247),
        profile: ColorProfile.trueColor,
      ).render('x');
      expect(out, contains('\x1b[38;2;203;166;247m'));
    });

    test('ansi256 profile downgrades RGB to nearest 256-color index', () {
      final out = const Style(
        foregroundRgb: RgbColor(0, 0, 0), // black → index 0 or 16
        profile: ColorProfile.ansi256,
      ).render('x');
      expect(out, matches(RegExp(r'\x1b\[38;5;\d+m')));
    });

    test('ansi profile downgrades RGB to nearest ansi16', () {
      final out = const Style(
        foregroundRgb: RgbColor(255, 0, 0), // red → ansi red
        profile: ColorProfile.ansi,
      ).render('x');
      expect(out, matches(RegExp(r'\x1b\[3[0-7]m')));
    });

    test('noColor profile strips all color codes', () {
      final out = const Style(
        foregroundRgb: RgbColor(255, 0, 128),
        backgroundRgb: RgbColor(30, 30, 46),
        isBold: true,
        profile: ColorProfile.noColor,
      ).render('test');
      // No color codes, but bold should still be suppressed (noColor = no color)
      expect(out, isNot(contains('\x1b[38;2;')));
      expect(out, isNot(contains('\x1b[48;2;')));
    });

    test('ansi256 profile with 256-color index passes through unchanged', () {
      final out = const Style(
        foreground256: 196, // bright red
        profile: ColorProfile.ansi256,
      ).render('x');
      expect(out, contains('\x1b[38;5;196m'));
    });

    test('ansi profile downgrades 256-color to ansi16', () {
      final out = const Style(
        foreground256: 196,
        profile: ColorProfile.ansi,
      ).render('x');
      // Should convert 256→rgb→ansi16
      expect(out, matches(RegExp(r'\x1b\[3[0-7]m|\x1b\[9[0-7]m')));
    });
  });

  group('Background color detection (isDarkRgb)', () {
    test('pure black is dark', () => expect(isDarkRgb(0x000000), isTrue));
    test('pure white is light', () => expect(isDarkRgb(0xFFFFFF), isFalse));

    test('mid-gray 0x808080 is light side (lum≈128)', () {
      // lum of 0x808080 = 0.2126*128 + 0.7152*128 + 0.0722*128 ≈ 128
      // The formula uses < 128, so exactly 128 → not dark
      expect(isDarkRgb(0x808080), isFalse);
    });

    test('catppuccin mocha base #1E1E2E is dark', () {
      expect(isDarkRgb(0x1E1E2E), isTrue);
    });

    test('nord snow storm #ECEFF4 is light', () {
      expect(isDarkRgb(0xECEFF4), isFalse);
    });
  });
}
