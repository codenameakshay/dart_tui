import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// A column definition for [TableModel].
final class TableColumn {
  const TableColumn({required this.title, required this.width});
  final String title;
  final int width;
}

/// Tabular data viewer with keyboard navigation.
final class TableModel extends TeaModel {
  TableModel({
    required this.columns,
    required this.rows,
    this.cursor = 0,
    this.scrollOffset = 0,
    this.height = 10,
    this.focusedRowStyle,
    this.blurredRowStyle,
  });

  final List<TableColumn> columns;
  final List<List<String>> rows;
  final int cursor;
  final int scrollOffset;
  final int height;
  final Style? focusedRowStyle;
  final Style? blurredRowStyle;

  TableModel copyWith({
    List<TableColumn>? columns,
    List<List<String>>? rows,
    int? cursor,
    int? scrollOffset,
    int? height,
    Style? focusedRowStyle,
    Style? blurredRowStyle,
  }) =>
      TableModel(
        columns: columns ?? this.columns,
        rows: rows ?? this.rows,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height ?? this.height,
        focusedRowStyle: focusedRowStyle ?? this.focusedRowStyle,
        blurredRowStyle: blurredRowStyle ?? this.blurredRowStyle,
      );

  TableModel _moveCursor(int delta) {
    final newCursor =
        (cursor + delta).clamp(0, rows.isEmpty ? 0 : rows.length - 1);
    var newOffset = scrollOffset;
    if (newCursor < newOffset) newOffset = newCursor;
    if (newCursor >= newOffset + height) newOffset = newCursor - height + 1;
    return copyWith(cursor: newCursor, scrollOffset: newOffset);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (_moveCursor(-1), null);
      case 'down':
      case 'j':
        return (_moveCursor(1), null);
      case 'pgup':
        return (_moveCursor(-height), null);
      case 'pgdown':
        return (_moveCursor(height), null);
      case 'home':
        return (_moveCursor(-rows.length), null);
      case 'end':
        return (_moveCursor(rows.length), null);
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final b = StringBuffer();

    // Header
    final header = columns
        .map((c) => c.title.length > c.width
            ? c.title.substring(0, c.width)
            : c.title.padRight(c.width))
        .join(' │ ');
    b.writeln(header);

    // Separator
    final sep = columns.map((c) => '─' * c.width).join('─┼─');
    b.writeln(sep);

    // Rows
    final end = (scrollOffset + height).clamp(0, rows.length);
    for (var i = scrollOffset; i < end; i++) {
      final row = rows[i];
      final cells = List.generate(columns.length, (ci) {
        final cell = ci < row.length ? row[ci] : '';
        return cell.length > columns[ci].width
            ? cell.substring(0, columns[ci].width)
            : cell.padRight(columns[ci].width);
      });
      final line = cells.join(' │ ');
      if (i == cursor) {
        b.write('> $line');
      } else {
        b.write('  $line');
      }
      if (i < end - 1) b.writeln();
    }

    return newView(b.toString());
  }
}
