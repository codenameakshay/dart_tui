import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a single printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  group('ViewportModel', () {
    final content = List.generate(20, (i) => 'line $i').join('\n');

    test('starts at top', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.atTop, isTrue);
      expect(vp.yOffset, 0);
    });

    test('scrollBy clamps at bottom', () {
      final vp = ViewportModel(content: content, height: 5);
      final scrolled = vp.scrollBy(100);
      expect(scrolled.yOffset, 15); // 20 - 5
    });

    test('atBottom is true when at end', () {
      final vp = ViewportModel(content: content, height: 5).scrollBy(100);
      expect(vp.atBottom, isTrue);
    });

    test('scrollPercent is 0 at top, 1 at bottom', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.scrollPercent, 0.0);
      expect(vp.scrollBy(100).scrollPercent, 1.0);
    });

    test('setContent resets offset', () {
      final vp = ViewportModel(content: content, height: 5).scrollBy(5);
      final reset = vp.setContent('new content');
      expect(reset.yOffset, 0);
    });

    test('totalLines returns correct count', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.totalLines, 20);
    });
  });
}
