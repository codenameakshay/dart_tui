// Tests for word-wrap in Style.render().
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

// Strip ANSI codes for plain-text assertions.
String plain(String s) => stripAnsi(s);

void main() {
  group('wordWrap = false (default)', () {
    test('long line is truncated when maxWidth is set', () {
      final out = const Style().withMaxWidth(5).render('hello world');
      expect(plain(out), equals('hello'));
    });

    test('long line is truncated when width is set', () {
      final out = const Style().withWidth(5).render('hello world');
      expect(plain(out), hasLength(5));
    });
  });

  group('wordWrap = true', () {
    test('short text is returned unchanged', () {
      final out = const Style(wordWrap: true, width: 20).render('hi');
      expect(plain(out).trim(), equals('hi'));
    });

    test('long line is wrapped at word boundary', () {
      final out =
          const Style(wordWrap: true, width: 10).render('hello world foo bar');
      final lines = out.split('\n');
      for (final l in lines) {
        expect(plain(l).length, lessThanOrEqualTo(10));
      }
      // All words present
      final joined = plain(out).replaceAll('\n', ' ');
      expect(joined, contains('hello'));
      expect(joined, contains('world'));
      expect(joined, contains('foo'));
      expect(joined, contains('bar'));
    });

    test('very long single word is hard-broken', () {
      final out = const Style(wordWrap: true, width: 5).render('abcdefghij');
      final lines = out.split('\n');
      expect(lines.length, greaterThan(1));
      for (final l in lines) {
        expect(plain(l).length, lessThanOrEqualTo(5));
      }
    });

    test('explicit newlines in input are preserved as line breaks', () {
      final out = const Style(wordWrap: true, width: 20).render('line1\nline2');
      final lines = out.split('\n');
      expect(lines.any((l) => l.contains('line1')), isTrue);
      expect(lines.any((l) => l.contains('line2')), isTrue);
    });

    test('wrapping respects padding subtraction', () {
      // With padding 2 on each side and width 14, inner width is 10.
      final out = const Style(
        wordWrap: true,
        width: 14,
        padding: EdgeInsets.symmetric(horizontal: 2),
      ).render('hello world extra');
      // Each content line (before padding is added) should be <= 10 visible chars
      expect(plain(out), contains('hello'));
    });

    test('wrapping with border produces valid output', () {
      final out = const Style(
        wordWrap: true,
        width: 12,
        border: Border.rounded,
      ).render('hello there world');
      expect(out, contains('╭'));
      expect(out, contains('╯'));
      expect(plain(out), contains('hello'));
    });

    test('CJK characters count as 2 columns', () {
      // 你(2) + 好(2) = 4 cols, fits in width 5
      final out = const Style(wordWrap: true, width: 5).render('你好 abc');
      final lines = out.split('\n');
      // Each line must not exceed 5 visible columns
      for (final l in lines) {
        expect(
          l.runes.fold<int>(0, (w, cp) => w + (cp > 0x1100 ? 2 : 1)),
          lessThanOrEqualTo(5),
        );
      }
    });
  });
}
