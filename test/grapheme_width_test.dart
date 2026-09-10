import 'package:dart_tui/dart_tui.dart' show getWidth;
import 'package:dart_tui/src/grapheme_width.dart';
import 'package:test/test.dart';

void main() {
  group('graphemeWidth', () {
    test('measures terminal grapheme clusters instead of first code points',
        () {
      expect(graphemeWidth(''), 0);
      expect(graphemeWidth('\u0301'), 0);
      expect(graphemeWidth('e\u0301'), 1);
      expect(graphemeWidth('A'), 1);
      expect(graphemeWidth('界'), 2);
      expect(graphemeWidth('❤️'), 2);
      expect(graphemeWidth('🇮🇳'), 2);
      expect(graphemeWidth('👍🏽'), 2);
      expect(graphemeWidth('👨‍👩‍👧‍👦'), 2);
      expect(graphemeWidth('1️⃣'), 2);
    });

    test('measures mixed strings by grapheme cluster', () {
      expect(textWidth('A❤️界e\u0301'), 6);
      expect(textWidth('🇮🇳👍🏽'), 4);
      expect(getWidth('\x1b[31mA❤️界e\u0301\x1b[0m'), 6);
    });
  });

  group('textWidth ASCII fast path', () {
    test('empty string', () {
      expect(textWidth(''), 0);
    });

    test('plain ASCII', () {
      expect(textWidth('hello'), 5);
    });

    test('ASCII with newline', () {
      expect(textWidth('hello\nworld'), 10);
    });

    test('ANSI escape sequence', () {
      const ansi = '\x1b[31m';
      expect(textWidth(ansi), 4);
    });

    test('CJK takes slow path', () {
      expect(textWidth('你好'), 4);
    });

    test('combining mark takes slow path', () {
      expect(textWidth('e\u0301'), 1);
    });

    test('mixed emoji and CJK', () {
      expect(textWidth('A❤️界'), 5);
    });

    test('C0 controls and DEL are zero width', () {
      expect(textWidth('\x00\x07\x1f\x7f'), 0);
    });

    test('mixed ASCII then CJK', () {
      expect(textWidth('ab你'), 4);
    });
  });
}
