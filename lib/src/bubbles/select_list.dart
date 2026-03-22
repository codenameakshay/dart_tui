import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// Style configuration for [SelectListModel].
final class ListStyles {
  const ListStyles({
    this.title = const Style(),
    this.selectedItem = const Style(),
    this.normalItem = const Style(),
    this.cursor = const Style(),
  });

  /// Applied to the optional title header.
  final Style title;

  /// Applied to the currently selected item text.
  final Style selectedItem;

  /// Applied to all other item texts.
  final Style normalItem;

  /// Applied to the cursor indicator character (`›`).
  final Style cursor;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const ListStyles defaults = ListStyles(
    title: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
      isBold: true,
    ),
    selectedItem: Style(
      foregroundRgb: RgbColor(30, 30, 46), // Base (dark text on accent bg)
      backgroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    normalItem: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
    ),
    cursor: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
  );
}

/// Vertical list with a cursor (arrow keys). Reusable building block.
final class SelectListModel extends TeaModel {
  SelectListModel({
    required this.items,
    this.cursor = 0,
    this.title = '',
    this.styles = ListStyles.defaults,
  }) : assert(items.isNotEmpty, 'items must not be empty');

  final List<String> items;
  final int cursor;
  final String title;
  final ListStyles styles;

  int get _safeCursor => cursor.clamp(0, items.length - 1);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        final c = _safeCursor;
        final next = c > 0 ? c - 1 : 0;
        return (
          SelectListModel(items: items, cursor: next, title: title, styles: styles),
          null
        );
      case 'down':
      case 'j':
        final c = _safeCursor;
        final next = c < items.length - 1 ? c + 1 : items.length - 1;
        return (
          SelectListModel(items: items, cursor: next, title: title, styles: styles),
          null
        );
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final b = StringBuffer();
    if (title.isNotEmpty) {
      b.writeln(styles.title.render(title));
      b.writeln();
    }
    final cur = _safeCursor;
    for (var i = 0; i < items.length; i++) {
      if (i == cur) {
        b.writeln('${styles.cursor.render('›')} ${styles.selectedItem.render(items[i])}');
      } else {
        b.writeln('  ${styles.normalItem.render(items[i])}');
      }
    }
    return newView(b.toString());
  }
}
