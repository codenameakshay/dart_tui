import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// A single option in a [MultiSelectModel].
final class MultiSelectItem {
  const MultiSelectItem({
    required this.label,
    this.value = '',
    this.selected = false,
  });

  /// Display label shown in the list.
  final String label;

  /// Arbitrary value associated with this item (defaults to [label]).
  final String value;

  /// Whether the item is currently checked.
  final bool selected;

  MultiSelectItem copyWith({String? label, String? value, bool? selected}) =>
      MultiSelectItem(
        label: label ?? this.label,
        value: value ?? this.value,
        selected: selected ?? this.selected,
      );

  String get _value => value.isNotEmpty ? value : label;
}

/// Style configuration for [MultiSelectModel].
final class MultiSelectStyles {
  const MultiSelectStyles({
    this.title = const Style(),
    this.cursor = const Style(),
    this.selectedItem = const Style(),
    this.normalItem = const Style(),
    this.checkedBox = const Style(),
    this.uncheckedBox = const Style(),
    this.statusBar = const Style(),
  });

  /// Applied to the optional title header.
  final Style title;

  /// Applied to the cursor indicator character (`›`).
  final Style cursor;

  /// Applied to selected (checked) item text.
  final Style selectedItem;

  /// Applied to unselected item text.
  final Style normalItem;

  /// Applied to the checked box character (`[x]`).
  final Style checkedBox;

  /// Applied to the unchecked box character (`[ ]`).
  final Style uncheckedBox;

  /// Applied to the status bar (`n selected`).
  final Style statusBar;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const MultiSelectStyles defaults = MultiSelectStyles(
    title: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
      isBold: true,
    ),
    cursor: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    selectedItem: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
    ),
    normalItem: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
    ),
    checkedBox: Style(
      foregroundRgb: RgbColor(166, 227, 161), // Green
      isBold: true,
    ),
    uncheckedBox: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
    ),
    statusBar: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
      isDim: true,
    ),
  );
}

/// Scrollable checkbox list supporting multiple concurrent selections.
///
/// Navigation: `↑`/`k` up, `↓`/`j` down, `Space` or `x` toggle selection,
/// `a` toggle all, `Enter` confirm (propagated to parent).
///
/// Typical usage:
/// ```dart
/// final multi = MultiSelectModel(items: [
///   MultiSelectItem(label: 'Dart'),
///   MultiSelectItem(label: 'Flutter'),
///   MultiSelectItem(label: 'Go'),
/// ]);
///
/// // In parent update():
/// final (nextMulti, cmd) = multi.update(msg);
/// multi = nextMulti as MultiSelectModel;
/// if (msg is KeyMsg && msg.key == 'enter') {
///   handleSelections(multi.selected);
/// }
/// ```
final class MultiSelectModel extends TeaModel {
  MultiSelectModel({
    required this.items,
    this.cursor = 0,
    this.title = '',
    this.height = 10,
    this.showStatusBar = true,
    this.wrap = false,
    this.styles = MultiSelectStyles.defaults,
  });

  final List<MultiSelectItem> items;
  final int cursor;
  final String title;

  /// Maximum number of item rows to show at once (viewport height).
  final int height;

  /// Whether to show the `n selected` status bar.
  final bool showStatusBar;

  /// Whether cursor navigation wraps around at the list boundaries.
  final bool wrap;

  final MultiSelectStyles styles;

  int get _safeCursor =>
      items.isEmpty ? 0 : cursor.clamp(0, items.length - 1);

  /// All items with [MultiSelectItem.selected] == `true`.
  List<MultiSelectItem> get selected =>
      items.where((i) => i.selected).toList();

  /// Values of all selected items.
  List<String> get selectedValues => selected.map((i) => i._value).toList();

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final cur = _safeCursor;

    switch (msg.key) {
      case 'up':
      case 'k':
        final next = cur > 0
            ? cur - 1
            : (wrap ? items.length - 1 : 0);
        return (_copy(cursor: next), null);

      case 'down':
      case 'j':
        final next = cur < items.length - 1
            ? cur + 1
            : (wrap ? 0 : items.length - 1);
        return (_copy(cursor: next), null);

      case ' ':
      case 'x':
        return (_toggleAt(cur), null);

      case 'a':
        // Toggle all: if every item is selected, deselect all; otherwise select all.
        final allSelected = items.every((i) => i.selected);
        final toggled = items.map((i) => i.copyWith(selected: !allSelected)).toList();
        return (_copy(items: toggled), null);

      default:
        return (this, null);
    }
  }

  MultiSelectModel _toggleAt(int index) {
    if (items.isEmpty) return this;
    final toggled = List<MultiSelectItem>.from(items);
    toggled[index] = toggled[index].copyWith(selected: !toggled[index].selected);
    return _copy(items: toggled);
  }

  MultiSelectModel _copy({
    List<MultiSelectItem>? items,
    int? cursor,
  }) =>
      MultiSelectModel(
        items: items ?? this.items,
        cursor: cursor ?? _safeCursor,
        title: title,
        height: height,
        showStatusBar: showStatusBar,
        wrap: wrap,
        styles: styles,
      );

  @override
  View view() {
    final b = StringBuffer();

    if (title.isNotEmpty) {
      b.writeln(styles.title.render(title));
      b.writeln();
    }

    if (items.isEmpty) {
      return newView(b.toString());
    }

    final cur = _safeCursor;
    final start = _viewportStart(cur, items.length, height);
    final end = (start + height).clamp(0, items.length);

    for (var i = start; i < end; i++) {
      final item = items[i];
      final box = item.selected
          ? styles.checkedBox.render('[x]')
          : styles.uncheckedBox.render('[ ]');
      final label = i == cur
          ? '${styles.cursor.render('›')} $box ${styles.selectedItem.render(item.label)}'
          : '  $box ${styles.normalItem.render(item.label)}';
      if (i < end - 1) {
        b.writeln(label);
      } else {
        b.write(label);
      }
    }

    if (showStatusBar) {
      final n = selected.length;
      b.writeln();
      b.write(styles.statusBar.render('$n/${items.length} selected'));
    }

    return newView(b.toString());
  }

  /// Returns the viewport start index to keep [cursor] visible.
  static int _viewportStart(int cursor, int total, int height) {
    if (total <= height) return 0;
    final ideal = cursor - height ~/ 2;
    return ideal.clamp(0, total - height);
  }
}
