// Tests for border color, border title, and combined Style pipeline.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('Border coloring', () {
    test('borderForeground wraps border chars in RGB ANSI open sequence', () {
      final out = const Style(
        border: Border.rounded,
        borderForeground: RgbColor(203, 166, 247),
      ).render('x');
      // Open: \x1b[38;2;203;166;247m
      expect(out, contains('\x1b[38;2;203;166;247m'));
      // Border chars are present
      expect(out, contains('╭'));
      expect(out, contains('╯'));
    });

    test('borderBackground wraps border chars in RGB bg sequence', () {
      final out = const Style(
        border: Border.box,
        borderBackground: RgbColor(49, 50, 68),
      ).render('hello');
      expect(out, contains('\x1b[48;2;49;50;68m'));
      expect(out, contains('┌'));
    });

    test('borderForeground and borderBackground can combine', () {
      final out = const Style(
        border: Border.thick,
        borderForeground: RgbColor(255, 0, 0),
        borderBackground: RgbColor(0, 0, 255),
      ).render('test');
      expect(out, contains('\x1b[38;2;255;0;0m'));
      expect(out, contains('\x1b[48;2;0;0;255m'));
    });

    test('no borderForeground/borderBackground: border chars have no color codes', () {
      final out = const Style(border: Border.rounded).render('text');
      final lines = out.split('\n');
      // Top border line should have no RGB codes
      expect(lines.first, isNot(contains('\x1b[38;2;')));
      expect(lines.first, isNot(contains('\x1b[48;2;')));
    });

    test('border content is separate from border coloring', () {
      // Content color should not bleed into border characters
      final out = const Style(
        border: Border.rounded,
        foregroundRgb: RgbColor(100, 200, 50), // content color
        borderForeground: RgbColor(203, 166, 247), // border color
      ).render('x');
      expect(out, contains('\x1b[38;2;203;166;247m')); // border color
      expect(out, contains('\x1b[38;2;100;200;50m')); // content color
    });
  });

  group('Border title', () {
    test('borderTitle is embedded in the top edge', () {
      final out = const Style(
        border: Border.rounded,
        borderTitle: 'My Box',
      ).render('content');
      // The title should appear somewhere in the first line
      expect(out.split('\n').first, contains('My Box'));
    });

    test('borderTitle with left alignment has no dashes on the left', () {
      final out = const Style(
        border: Border.rounded,
        borderTitle: 'Title',
        borderTitleAlignment: Align.left,
        width: 20,
      ).render('hi');
      final topLine = out.split('\n').first;
      // The top-left corner should be immediately followed by the title
      // (0 dashes before it when left-aligned)
      expect(topLine.contains('╭Title'), isTrue);
    });

    test('borderTitle with right alignment has no dashes on the right', () {
      final out = const Style(
        border: Border.rounded,
        borderTitle: 'Title',
        borderTitleAlignment: Align.right,
        width: 20,
      ).render('hi');
      final topLine = out.split('\n').first;
      expect(topLine.contains('Title╮'), isTrue);
    });

    test('borderTitle with center alignment has dashes on both sides', () {
      final out = const Style(
        border: Border.rounded,
        borderTitle: 'T',
        borderTitleAlignment: Align.center,
        width: 15,
      ).render('hi');
      final topLine = out.split('\n').first;
      // There should be dashes on both sides of the title
      final titleIdx = topLine.indexOf('T');
      expect(titleIdx, greaterThan(1)); // at least one dash before
      expect(titleIdx, lessThan(topLine.length - 2)); // and after
    });

    test('top border without title is just horizontal dashes', () {
      final out = const Style(border: Border.rounded).withWidth(10).render('x');
      final topLine = stripAnsi(out.split('\n').first);
      // All inner chars should be '─'
      final inner = topLine.substring(1, topLine.length - 1);
      expect(inner.split(''), everyElement(equals('─')));
    });
  });

  group('Style pipeline combinations', () {
    test('border + padding + alignment all applied correctly', () {
      final out = const Style(
        border: Border.rounded,
        padding: EdgeInsets.all(1),
        width: 20,
        align: Align.center,
      ).render('hi');
      final lines = out.split('\n');
      // Has top border
      expect(lines.first, contains('╭'));
      // Has bottom border
      expect(lines.last, contains('╰'));
      // Content is padded
      expect(lines.length, greaterThan(3));
    });

    test('maxHeight truncates excess lines', () {
      final out = const Style().withMaxHeight(2).render('a\nb\nc\nd');
      final lines = out.split('\n');
      expect(lines.length, 2);
    });

    test('border + maxHeight limits rows', () {
      final out = const Style(
        border: Border.box,
        maxHeight: 2,
      ).render('line1\nline2\nline3\nline4');
      final lines = out.split('\n');
      // top border + 2 content lines + bottom border = 4
      expect(lines.length, 4);
    });

    test('width + height + vertical alignment middle', () {
      final out = const Style(
        width: 10,
        height: 5,
        alignVertical: AlignVertical.middle,
      ).render('hi');
      final lines = out.split('\n');
      expect(lines.length, 5);
      // Middle line should contain 'hi'
      expect(lines[2], contains('hi'));
    });

    test('CJK content with border aligns correctly', () {
      // Each CJK char is 2 columns wide
      final out = const Style(border: Border.rounded).render('你好');
      expect(out, contains('你好'));
      expect(out, contains('╭'));
    });
  });
}
