// Tests for gradientText and gradientBackground.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('gradientText', () {
    test('requires at least 2 colors', () {
      expect(
        () => gradientText('hi', [const RgbColor(255, 0, 0)]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty text returns empty string', () {
      expect(
        gradientText(
            '', [const RgbColor(0, 0, 255), const RgbColor(255, 0, 0)]),
        equals(''),
      );
    });

    test('each character gets a true-color ANSI code', () {
      final out = gradientText(
          'abc', [const RgbColor(0, 0, 255), const RgbColor(255, 0, 0)]);
      // 3 characters → 3 '\x1b[38;2;' sequences
      final count = '\x1b[38;2;'.allMatches(out).length;
      expect(count, equals(3));
    });

    test('output ends with reset', () {
      final out = gradientText(
          'hi', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      expect(out, endsWith('\x1b[0m'));
    });

    test('first char gets first color, last char gets last color', () {
      final out = gradientText('ab', [
        const RgbColor(0, 0, 0),
        const RgbColor(255, 255, 255),
      ]);
      expect(out, startsWith('\x1b[38;2;0;0;0m'));
      expect(out, contains('\x1b[38;2;255;255;255m'));
    });

    test('single character uses first color', () {
      final out = gradientText(
          'x', [const RgbColor(100, 200, 50), const RgbColor(50, 100, 200)]);
      expect(out, contains('\x1b[38;2;100;200;50m'));
    });

    test('text content is preserved in output', () {
      final out = gradientText(
          'Hello', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      final stripped = stripAnsi(out);
      expect(stripped, equals('Hello'));
    });

    test('CJK characters are handled as single grapheme clusters', () {
      final out = gradientText(
          '你好', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      expect(out, contains('你'));
      expect(out, contains('好'));
    });

    test('three-color gradient interpolates through middle', () {
      final out = gradientText('abc', [
        const RgbColor(0, 0, 0),
        const RgbColor(128, 128, 128),
        const RgbColor(255, 255, 255),
      ]);
      // 3 chars → 3 codes; middle char should get ~(128,128,128)
      expect(out, contains('\x1b[38;2;'));
      final stripped = stripAnsi(out);
      expect(stripped, equals('abc'));
    });
  });

  group('gradientBackground', () {
    test('requires at least 2 colors', () {
      expect(
        () => gradientBackground('hi', [const RgbColor(0, 0, 0)]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty text returns empty string', () {
      final out = gradientBackground(
          '', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      expect(out, equals(''));
    });

    test('uses background ANSI codes \\x1b[48;2;', () {
      final out = gradientBackground(
          'abc', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      expect(out, contains('\x1b[48;2;'));
    });

    test('foreground style is applied when provided', () {
      final out = gradientBackground(
        'hi',
        [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)],
        foreground: const Style(foregroundRgb: RgbColor(203, 166, 247)),
      );
      expect(out, contains('\x1b[38;2;203;166;247m'));
    });

    test('text content preserved', () {
      final out = gradientBackground(
          'Test', [const RgbColor(0, 0, 0), const RgbColor(255, 255, 255)]);
      expect(stripAnsi(out), equals('Test'));
    });
  });

  group('color utilities', () {
    test('blend returns interpolated color', () {
      final result =
          blend(const RgbColor(0, 0, 0), const RgbColor(100, 200, 50), 0.5);
      expect(result.r, closeTo(50, 1));
      expect(result.g, closeTo(100, 1));
      expect(result.b, closeTo(25, 1));
    });

    test('blend t=0 returns first color', () {
      const a = RgbColor(10, 20, 30);
      const b = RgbColor(100, 200, 50);
      final result = blend(a, b, 0.0);
      expect(result, equals(a));
    });

    test('blend t=1 returns second color', () {
      const a = RgbColor(10, 20, 30);
      const b = RgbColor(100, 200, 50);
      final result = blend(a, b, 1.0);
      expect(result, equals(b));
    });

    test('lighten adds white', () {
      final result = lighten(const RgbColor(0, 0, 0), 0.5);
      expect(result.r, closeTo(127, 1));
    });

    test('darken removes white', () {
      final result = darken(const RgbColor(200, 200, 200), 0.5);
      expect(result.r, closeTo(100, 1));
    });

    test('isDarkRgb returns true for dark colors', () {
      // Black: 0x000000
      expect(isDarkRgb(0x000000), isTrue);
      // Dark gray: 0x222222
      expect(isDarkRgb(0x222222), isTrue);
    });

    test('isDarkRgb returns false for light colors', () {
      // White: 0xFFFFFF
      expect(isDarkRgb(0xFFFFFF), isFalse);
      // Light gray: 0xCCCCCC
      expect(isDarkRgb(0xCCCCCC), isFalse);
    });
  });
}
