import 'package:characters/characters.dart';

import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'text_input.dart' show InputStyles;

/// Multi-line text editor bubble.
///
/// Uses grapheme clusters for correct Unicode cursor positioning.
final class TextAreaModel extends TeaModel {
  TextAreaModel({
    this.value = '',
    this.cursorRow = 0,
    this.cursorCol = 0,
    this.scrollOffset = 0,
    this.maxHeight = 10,
    this.width = 60,
    this.charLimit = 0,
    this.focused = true,
    this.placeholder = '',
    this.styles = InputStyles.defaults,
  });

  final String value;
  final int cursorRow;
  final int cursorCol;
  final int scrollOffset;
  final int maxHeight;
  final int width;
  final int charLimit;
  final bool focused;
  final String placeholder;
  final InputStyles styles;

  /// Split [value] into lines.
  List<String> get lines => value.split('\n');

  TextAreaModel copyWith({
    String? value,
    int? cursorRow,
    int? cursorCol,
    int? scrollOffset,
    int? maxHeight,
    int? width,
    int? charLimit,
    bool? focused,
    String? placeholder,
    InputStyles? styles,
  }) =>
      TextAreaModel(
        value: value ?? this.value,
        cursorRow: cursorRow ?? this.cursorRow,
        cursorCol: cursorCol ?? this.cursorCol,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        maxHeight: maxHeight ?? this.maxHeight,
        width: width ?? this.width,
        charLimit: charLimit ?? this.charLimit,
        focused: focused ?? this.focused,
        placeholder: placeholder ?? this.placeholder,
        styles: styles ?? this.styles,
      );

  /// Insert [text] at the current cursor position.
  TextAreaModel _insertText(String text) {
    final ls = lines;
    final row = cursorRow.clamp(0, ls.length - 1);
    final lineChars = ls[row].characters.toList();
    final col = cursorCol.clamp(0, lineChars.length);
    lineChars.insert(col, text);
    ls[row] = lineChars.join();
    final newValue = ls.join('\n');
    if (charLimit > 0 && newValue.characters.length > charLimit) return this;
    return copyWith(value: newValue, cursorCol: col + 1);
  }

  /// Delete the character before the cursor.
  TextAreaModel _deleteBackward() {
    final ls = lines;
    final row = cursorRow.clamp(0, ls.length - 1);
    if (cursorCol > 0) {
      final lineChars = ls[row].characters.toList();
      lineChars.removeAt(cursorCol - 1);
      ls[row] = lineChars.join();
      return copyWith(value: ls.join('\n'), cursorCol: cursorCol - 1);
    } else if (row > 0) {
      // Merge with previous line
      final prevChars = ls[row - 1].characters.toList();
      final prevLen = prevChars.length;
      ls[row - 1] = prevChars.join() + ls[row];
      ls.removeAt(row);
      return copyWith(
        value: ls.join('\n'),
        cursorRow: row - 1,
        cursorCol: prevLen,
      );
    }
    return this;
  }

  /// Delete the character at the cursor.
  TextAreaModel _deleteForward() {
    final ls = lines;
    final row = cursorRow.clamp(0, ls.length - 1);
    final lineChars = ls[row].characters.toList();
    if (cursorCol < lineChars.length) {
      lineChars.removeAt(cursorCol);
      ls[row] = lineChars.join();
      return copyWith(value: ls.join('\n'));
    } else if (row < ls.length - 1) {
      // Merge next line
      ls[row] = ls[row] + ls[row + 1];
      ls.removeAt(row + 1);
      return copyWith(value: ls.join('\n'));
    }
    return this;
  }

  TextAreaModel _scroll(int newRow) {
    var offset = scrollOffset;
    if (newRow < offset) offset = newRow;
    if (newRow >= offset + maxHeight) offset = newRow - maxHeight + 1;
    return copyWith(scrollOffset: offset);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final ls = lines;
    final row = cursorRow.clamp(0, ls.length - 1);
    final lineChars = ls[row].characters.toList();
    final lineLen = lineChars.length;

    switch (msg.key) {
      case 'backspace':
        return (_deleteBackward()._scroll(cursorRow), null);

      case 'delete':
        return (_deleteForward(), null);

      case 'enter':
        if (charLimit > 0 && value.characters.length >= charLimit) return (this, null);
        final col = cursorCol.clamp(0, lineChars.length);
        final newLine = lineChars.sublist(0, col).join();
        final rest = lineChars.sublist(col).join();
        ls[row] = newLine;
        ls.insert(row + 1, rest);
        final next = copyWith(
          value: ls.join('\n'),
          cursorRow: row + 1,
          cursorCol: 0,
        );
        return (next._scroll(next.cursorRow), null);

      case 'up':
        if (row == 0) return (this, null);
        final newColUp = cursorCol.clamp(0, ls[row - 1].characters.length);
        final nextUp = copyWith(cursorRow: row - 1, cursorCol: newColUp);
        return (nextUp._scroll(nextUp.cursorRow), null);

      case 'down':
        if (row >= ls.length - 1) return (this, null);
        final newColDown = cursorCol.clamp(0, ls[row + 1].characters.length);
        final nextDown = copyWith(cursorRow: row + 1, cursorCol: newColDown);
        return (nextDown._scroll(nextDown.cursorRow), null);

      case 'left':
        if (cursorCol > 0) {
          return (copyWith(cursorCol: cursorCol - 1), null);
        } else if (row > 0) {
          final prevLen = ls[row - 1].characters.length;
          final nextLeft = copyWith(cursorRow: row - 1, cursorCol: prevLen);
          return (nextLeft._scroll(nextLeft.cursorRow), null);
        }
        return (this, null);

      case 'right':
        if (cursorCol < lineLen) {
          return (copyWith(cursorCol: cursorCol + 1), null);
        } else if (row < ls.length - 1) {
          final nextRight = copyWith(cursorRow: row + 1, cursorCol: 0);
          return (nextRight._scroll(nextRight.cursorRow), null);
        }
        return (this, null);

      case 'home':
        return (copyWith(cursorCol: 0), null);

      case 'end':
        return (copyWith(cursorCol: lineLen), null);

      default:
        // ctrl+k: kill to end of line
        if (msg.key == 'ctrl+k') {
          ls[row] = lineChars.sublist(0, cursorCol).join();
          return (copyWith(value: ls.join('\n')), null);
        }
        // ctrl+u: kill to start of line
        if (msg.key == 'ctrl+u') {
          ls[row] = lineChars.sublist(cursorCol).join();
          return (copyWith(value: ls.join('\n'), cursorCol: 0), null);
        }
        if (!focused) return (this, null);
        if (msg.key.length >= 1) {
          return (_insertText(msg.key)._scroll(cursorRow), null);
        }
        return (this, null);
    }
  }

  @override
  View view() {
    final ls = lines;
    if (ls.isEmpty || (ls.length == 1 && ls[0].isEmpty && !focused)) {
      return newView(styles.placeholder.render(placeholder));
    }

    final visibleStart = scrollOffset;
    final visibleEnd = (scrollOffset + maxHeight).clamp(0, ls.length);
    final visible = ls.sublist(visibleStart, visibleEnd);
    return newView(visible.map(styles.text.render).join('\n'));
  }
}
