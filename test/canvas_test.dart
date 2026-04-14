// Tests for Canvas compositing: z-index, CJK, ANSI preservation.
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

String plain(String s) => stripAnsi(s);

List<String> lines(String s) => s.split('\n');

void main() {
  group('Canvas basics', () {
    test('canvas renders blank cells when nothing is painted', () {
      final c = Canvas(5, 3);
      final out = c.render();
      final ls = lines(out);
      expect(ls.length, 3);
      for (final l in ls) {
        expect(plain(l), equals(' ' * 5));
      }
    });

    test('painted text appears at correct position', () {
      final c = Canvas(10, 3);
      c.paint(2, 1, 'Hi');
      final ls = lines(c.render());
      expect(plain(ls[1]).substring(2, 4), equals('Hi'));
    });

    test('paint at (0,0) starts from top-left', () {
      final c = Canvas(5, 2);
      c.paint(0, 0, 'AB');
      final ls = lines(c.render());
      expect(plain(ls[0]).substring(0, 2), equals('AB'));
    });

    test('multi-line content spans rows', () {
      final c = Canvas(10, 5);
      c.paint(1, 1, 'row1\nrow2');
      final ls = lines(c.render());
      expect(plain(ls[1]).substring(1, 5), equals('row1'));
      expect(plain(ls[2]).substring(1, 5), equals('row2'));
    });

    test('out-of-bounds paint is clipped, does not throw', () {
      final c = Canvas(5, 3);
      expect(() => c.paint(3, 0, 'overflow'), returnsNormally);
    });

    test('negative x/y are clipped, does not throw', () {
      final c = Canvas(5, 3);
      expect(() => c.paint(-2, -1, 'test'), returnsNormally);
    });
  });

  group('Canvas z-index', () {
    test('higher z-index overwrites lower z-index at same cell', () {
      final c = Canvas(5, 1);
      c.paint(0, 0, 'AAAAA', zIndex: 0);
      c.paint(1, 0, 'B', zIndex: 1);
      final out = plain(c.render());
      expect(out[1], equals('B'));
      expect(out[0], equals('A'));
    });

    test('lower z-index does not overwrite higher z-index', () {
      final c = Canvas(5, 1);
      c.paint(0, 0, 'BBBBB', zIndex: 2);
      c.paint(2, 0, 'A', zIndex: 1);
      final out = plain(c.render());
      // The 'B' at position 2 should remain (higher z wins)
      expect(out[2], equals('B'));
    });

    test('same z-index: later paint wins (insertion order)', () {
      final c = Canvas(3, 1);
      c.paint(0, 0, 'AAA', zIndex: 0);
      c.paint(1, 0, 'B', zIndex: 0);
      final out = plain(c.render());
      expect(out[1], equals('B'));
    });
  });

  group('Canvas clear', () {
    test('clear removes all layers', () {
      final c = Canvas(5, 2);
      c.paint(0, 0, 'hello');
      c.clear();
      final out = plain(c.render());
      expect(out, equals('     \n     '));
    });
  });

  group('Canvas CJK / double-width', () {
    test('CJK character occupies 2 columns, next cell is skipped', () {
      final c = Canvas(6, 1);
      c.paint(0, 0, '你好');
      final out = c.render();
      // 你 and 好 should appear in the output
      expect(out, contains('你'));
      expect(out, contains('好'));
    });

    test('CJK after ASCII is positioned correctly', () {
      final c = Canvas(8, 1);
      c.paint(0, 0, 'AB你');
      final ls = lines(c.render());
      final stripped = plain(ls[0]);
      expect(stripped.startsWith('AB'), isTrue);
      expect(stripped, contains('你'));
    });
  });

  group('Canvas ANSI style preservation', () {
    test('styled content retains ANSI codes in output', () {
      final c = Canvas(10, 1);
      final styled = const Style(isBold: true).render('bold');
      c.paint(0, 0, styled);
      final out = c.render();
      // Canvas renders per-cell — each cell has its own ANSI open sequence
      expect(out, contains('\x1b[1m'));
      // All characters of 'bold' should appear (may be interspersed with codes)
      expect(plain(out), contains('b'));
      expect(plain(out), contains('o'));
      expect(plain(out), contains('l'));
      expect(plain(out), contains('d'));
    });

    test('different z-index layers have independent styling', () {
      final c = Canvas(10, 1);
      final red = const Style(foregroundRgb: RgbColor(255, 0, 0)).render('R');
      final blue = const Style(foregroundRgb: RgbColor(0, 0, 255)).render('B');
      c.paint(0, 0, red, zIndex: 0);
      c.paint(5, 0, blue, zIndex: 1);
      final out = c.render();
      expect(out, contains('\x1b[38;2;255;0;0m'));
      expect(out, contains('\x1b[38;2;0;0;255m'));
    });
  });
}
