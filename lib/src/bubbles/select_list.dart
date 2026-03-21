import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Vertical list with a cursor (arrow keys). Reusable building block.
final class SelectListModel extends TeaModel {
  SelectListModel({
    required this.items,
    this.cursor = 0,
    this.title = '',
  }) : assert(items.isNotEmpty, 'items must not be empty');

  final List<String> items;
  final int cursor;
  final String title;

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
          SelectListModel(items: items, cursor: next, title: title),
          null
        );
      case 'down':
      case 'j':
        final c = _safeCursor;
        final next = c < items.length - 1 ? c + 1 : items.length - 1;
        return (
          SelectListModel(items: items, cursor: next, title: title),
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
      b.writeln(title);
      b.writeln();
    }
    final cur = _safeCursor;
    for (var i = 0; i < items.length; i++) {
      final mark = i == cur ? '>' : ' ';
      b.writeln('$mark ${items[i]}');
    }
    return newView(b.toString());
  }
}
