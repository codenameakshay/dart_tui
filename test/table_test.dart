import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a single printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  final cols = [
    const TableColumn(title: 'Name', width: 10),
    const TableColumn(title: 'Age', width: 5),
  ];
  final rows = [
    ['Alice', '30'],
    ['Bob', '25'],
    ['Carol', '35'],
  ];

  group('TableModel', () {
    test('starts with cursor at 0', () {
      final t = TableModel(columns: cols, rows: rows);
      expect(t.cursor, 0);
    });

    test('moves cursor down with j', () {
      final t = TableModel(columns: cols, rows: rows);
      final (next, _) = t.update(_char('j'));
      expect((next as TableModel).cursor, 1);
    });

    test('moves cursor up with k', () {
      final t = TableModel(columns: cols, rows: rows, cursor: 2);
      final (next, _) = t.update(_char('k'));
      expect((next as TableModel).cursor, 1);
    });

    test('cursor clamps at bottom', () {
      final t = TableModel(columns: cols, rows: rows, cursor: 2);
      final (next, _) = t.update(_char('j'));
      expect((next as TableModel).cursor, 2);
    });

    test('view contains header', () {
      final t = TableModel(columns: cols, rows: rows);
      final v = t.view();
      expect(v.content, contains('Name'));
      expect(v.content, contains('Age'));
    });

    test('view shows separator', () {
      final t = TableModel(columns: cols, rows: rows);
      expect(t.view().content, contains('─'));
    });
  });
}
