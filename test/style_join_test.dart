import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('joinHorizontal', () {
    test('joins two single-line blocks side by side', () {
      final result = joinHorizontal(AlignVertical.top, ['hello', 'world']);
      expect(result, equals('helloworld'));
    });

    test('pads shorter block to match tallest', () {
      final left = 'line1\nline2\nline3';
      final right = 'only';
      final result = joinHorizontal(AlignVertical.top, [left, right]);
      final lines = result.split('\n');
      expect(lines.length, 3);
    });

    test(
        'middle alignment (AlignVertical.middle) distributes blank lines evenly',
        () {
      final left = 'A\nB\nC\nD';
      final right = 'x';
      final result = joinHorizontal(AlignVertical.middle, [left, right]);
      final lines = result.split('\n');
      expect(lines.length, 4);
    });

    test('bottom alignment places short block at bottom', () {
      final left = 'A\nB\nC';
      final right = 'x';
      final result = joinHorizontal(AlignVertical.bottom, [left, right]);
      final lines = result.split('\n');
      expect(lines.length, 3);
      // The short block should be at the bottom — last line contains 'x'
      expect(lines.last, contains('x'));
    });
  });

  group('joinVertical', () {
    test('stacks blocks vertically', () {
      final result = joinVertical(Align.left, ['top', 'bottom']);
      expect(result, equals('top\nbottom'));
    });

    test('right-aligns narrower lines when alignment=right', () {
      final result = joinVertical(Align.right, ['hi', 'hello world']);
      final lines = result.split('\n');
      // Shorter line should be padded on the left
      expect(lines[0].startsWith(' '), isTrue);
    });

    test('center-aligns narrower lines when alignment=center', () {
      final result = joinVertical(Align.center, ['hi', 'hello world']);
      final lines = result.split('\n');
      expect(lines[0].startsWith(' '), isTrue);
      expect(lines[0].endsWith(' '), isTrue);
    });
  });

  group('place functions', () {
    test('placeHorizontal centers content', () {
      final result = placeHorizontal(10, Align.center, 'ab');
      expect(result.length, 10);
      expect(result.trim(), 'ab');
    });

    test('placeHorizontal right-aligns content', () {
      final result = placeHorizontal(10, Align.right, 'ab');
      expect(result.endsWith('ab'), isTrue);
    });

    test('placeVertical adds rows above and below', () {
      final result = placeVertical(5, AlignVertical.middle, 'line');
      final lines = result.split('\n');
      expect(lines.length, 5);
      final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
      expect(nonEmpty.length, 1);
      expect(nonEmpty.first, 'line');
    });

    test('placeVertical top puts content at first row', () {
      final result = placeVertical(5, AlignVertical.top, 'line');
      final lines = result.split('\n');
      expect(lines.first, 'line');
    });

    test('place combines horizontal and vertical', () {
      final result = place(10, 5, Align.center, AlignVertical.middle, 'hi');
      final lines = result.split('\n');
      expect(lines.length, 5);
    });
  });
}
