import 'dart:convert';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
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

  test('decoded wheel events scroll the cursor', () {
    final t = TableModel(columns: cols, rows: rows);
    final down =
        TerminalInputDecoder().feed(utf8.encode('\x1b[<65;5;6M')).single;
    final up = TerminalInputDecoder().feed(utf8.encode('\x1b[<64;5;6M')).single;
    final (a, _) = t.update(down);
    expect((a as TableModel).cursor, 1);
    final (b, _) = a.update(up);
    expect((b as TableModel).cursor, 0);
  });

  test('header and separator align with data rows', () {
    final lines = TableModel(columns: cols, rows: rows)
        .view()
        .content
        .split('\n')
        .map(stripAnsi)
        .toList();
    expect(lines[0].indexOf('│'), lines[2].indexOf('│'));
    expect(lines[1].indexOf('┼'), lines[2].indexOf('│'));
    expect(lines[1].length, lines[2].length);
  });
}
