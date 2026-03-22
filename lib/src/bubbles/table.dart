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

/// Per-cell style callback. [row] is the 0-based data row index (not counting
/// the header). [col] is the 0-based column index. Return the [Style] to apply
/// to that cell's text, or `null` to use the default row style.
typedef TableStyleFunc = Style? Function(int row, int col);

/// Style configuration for [TableModel].
final class TableStyles {
  const TableStyles({
    this.header = const Style(),
    this.selectedRow = const Style(),
    this.normalRow = const Style(),
    this.separator = const Style(),
    this.styleFunc,
  });

  /// Applied to header cell text.
  final Style header;

  /// Applied to the currently selected data row.
  final Style selectedRow;

  /// Applied to all non-selected data rows.
  final Style normalRow;

  /// Applied to the horizontal separator line between header and rows.
  final Style separator;

  /// Optional per-cell override. When non-null, called for each data cell
  /// instead of [selectedRow] / [normalRow]. Return `null` to fall back to
  /// the default row style.
  final TableStyleFunc? styleFunc;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const TableStyles defaults = TableStyles(
    header: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
      isBold: true,
      isUnderline: true,
    ),
    selectedRow: Style(
      backgroundRgb: RgbColor(49, 50, 68), // Surface0
    ),
    normalRow: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
    ),
    separator: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
    ),
  );
}

/// Tabular data viewer with keyboard navigation.
final class TableModel extends TeaModel {
  TableModel({
    required this.columns,
    required this.rows,
    this.cursor = 0,
    this.scrollOffset = 0,
    this.height = 10,
    this.styles = TableStyles.defaults,
  });

  final List<TableColumn> columns;
  final List<List<String>> rows;
  final int cursor;
  final int scrollOffset;
  final int height;
  final TableStyles styles;

  TableModel copyWith({
    List<TableColumn>? columns,
    List<List<String>>? rows,
    int? cursor,
    int? scrollOffset,
    int? height,
    TableStyles? styles,
  }) =>
      TableModel(
        columns: columns ?? this.columns,
        rows: rows ?? this.rows,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height ?? this.height,
        styles: styles ?? this.styles,
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
    final headerCells = columns.map((c) {
      final title = c.title.length > c.width
          ? c.title.substring(0, c.width)
          : c.title.padRight(c.width);
      return styles.header.render(title);
    }).join(' │ ');
    b.writeln(headerCells);

    // Separator
    final sepLine = columns.map((c) => '─' * c.width).join('─┼─');
    b.writeln(styles.separator.render(sepLine));

    // Rows
    final end = (scrollOffset + height).clamp(0, rows.length);
    for (var i = scrollOffset; i < end; i++) {
      final dataRowIndex = i; // 0-based data row index for styleFunc
      final row = rows[i];
      final isSelected = i == cursor;
      final cells = List.generate(columns.length, (ci) {
        final cell = ci < row.length ? row[ci] : '';
        final truncated = cell.length > columns[ci].width
            ? cell.substring(0, columns[ci].width)
            : cell.padRight(columns[ci].width);
        // Per-cell styleFunc takes priority
        final cellStyle = styles.styleFunc?.call(dataRowIndex, ci) ??
            (isSelected ? styles.selectedRow : styles.normalRow);
        return cellStyle.render(truncated);
      });
      final line = cells.join(' │ ');
      b.write(isSelected
          ? '${styles.selectedRow.render('›')} $line'
          : '  $line');
      if (i < end - 1) b.writeln();
    }

    return newView(b.toString());
  }
}
