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
}
