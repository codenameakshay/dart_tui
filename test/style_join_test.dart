import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('joinHorizontal', () {
    test('joins two single-line blocks side by side', () {
      final result = joinHorizontal(0.0, ['hello', 'world']);
      expect(result, equals('helloworld'));
    });

    test('pads shorter block to match tallest', () {
      final left = 'line1\nline2\nline3';
      final right = 'only';
      final result = joinHorizontal(0.0, [left, right]);
      final lines = result.split('\n');
      expect(lines.length, 3);
    });

    test('center alignment (0.5) distributes blank lines evenly', () {
      final left = 'A\nB\nC\nD';
      final right = 'x';
      final result = joinHorizontal(0.5, [left, right]);
      final lines = result.split('\n');
      expect(lines.length, 4);
    });
  });

  group('joinVertical', () {
    test('stacks blocks vertically', () {
      final result = joinVertical(0.0, ['top', 'bottom']);
      expect(result, equals('top\nbottom'));
    });

    test('right-aligns narrower lines when alignment=1.0', () {
      final result = joinVertical(1.0, ['hi', 'hello world']);
      final lines = result.split('\n');
      // Shorter line should be padded on the left
      expect(lines[0].startsWith(' '), isTrue);
    });
  });

  group('place functions', () {
    test('placeHorizontal centers content', () {
      final result = placeHorizontal(10, 0.5, 'ab');
      expect(result.length, 10);
      expect(result.trim(), 'ab');
    });

    test('placeVertical adds rows above and below', () {
      final result = placeVertical(5, 0.5, 'line');
      final lines = result.split('\n');
      expect(lines.length, 5);
      // Middle element is the content
      final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
      expect(nonEmpty.length, 1);
      expect(nonEmpty.first, 'line');
    });

    test('place combines horizontal and vertical', () {
      final result = place(10, 5, 0.5, 0.5, 'hi');
      final lines = result.split('\n');
      expect(lines.length, 5);
    });
  });
}
