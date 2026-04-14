import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  group('PaginatorModel', () {
    test('safePage clamps to valid range', () {
      final p = PaginatorModel(page: -1, totalPages: 5);
      expect(p.safePage, 0);
      final p2 = PaginatorModel(page: 10, totalPages: 5);
      expect(p2.safePage, 4);
    });

    test('right arrow advances page', () {
      final p = PaginatorModel(page: 0, totalPages: 3);
      final (next, _) = p.update(_special(KeyCode.right));
      expect((next as PaginatorModel).safePage, 1);
    });

    test('left arrow goes back', () {
      final p = PaginatorModel(page: 2, totalPages: 3);
      final (next, _) = p.update(_special(KeyCode.left));
      expect((next as PaginatorModel).safePage, 1);
    });

    test('does not go past last page', () {
      final p = PaginatorModel(page: 2, totalPages: 3);
      final (next, _) = p.update(_special(KeyCode.right));
      expect((next as PaginatorModel).safePage, 2);
    });

    test('does not go before page 0', () {
      final p = PaginatorModel(page: 0, totalPages: 3);
      final (next, _) = p.update(_special(KeyCode.left));
      expect((next as PaginatorModel).safePage, 0);
    });

    test('h/l keys navigate', () {
      final p = PaginatorModel(page: 1, totalPages: 3);
      final (nextL, _) = p.update(_char('l'));
      expect((nextL as PaginatorModel).safePage, 2);
      final (nextH, _) = p.update(_char('h'));
      expect((nextH as PaginatorModel).safePage, 0);
    });

    test('pgup/pgdown navigate', () {
      final p = PaginatorModel(page: 1, totalPages: 3);
      final (nextUp, _) = p.update(_special(KeyCode.pageUp));
      expect((nextUp as PaginatorModel).safePage, 0);
      final (nextDown, _) = p.update(_special(KeyCode.pageDown));
      expect((nextDown as PaginatorModel).safePage, 2);
    });

    test('default view shows page count', () {
      final p = PaginatorModel(page: 1, totalPages: 5);
      expect(p.view().content, contains('2/5'));
    });

    test('custom labelBuilder is used', () {
      final p = PaginatorModel(
        page: 0,
        totalPages: 3,
        labelBuilder: (page, total) => 'Step ${page + 1} of $total',
      );
      expect(p.view().content, 'Step 1 of 3');
    });

    test('assert throws for totalPages <= 0', () {
      expect(
        () => PaginatorModel(page: 0, totalPages: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('non-navigation msgs are ignored', () {
      final p = PaginatorModel(page: 0, totalPages: 3);
      final (next, _) = p.update(TickMsg(DateTime.now()));
      expect(identical(p, next), isTrue);
    });
  });
}
