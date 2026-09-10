import 'package:characters/characters.dart';

import '../cmd.dart';
import '../grapheme_width.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// Style configuration for [TextAreaModel].
final class TextAreaStyles {
  const TextAreaStyles({
    this.text = const Style(),
    this.placeholder = const Style(),
  });

  factory TextAreaStyles.forDarkBackground(bool isDark) =>
      isDark ? dark : light;

  factory TextAreaStyles.forBackground(int rgb) =>
      TextAreaStyles.forDarkBackground(isDarkRgb(rgb));

  final Style text;
  final Style placeholder;

  static const TextAreaStyles dark = TextAreaStyles(
    text: Style(foregroundRgb: RgbColor(205, 214, 244)),
    placeholder: Style(
      foregroundRgb: RgbColor(108, 112, 134),
      isDim: true,
      isItalic: true,
    ),
  );

  static const TextAreaStyles light = TextAreaStyles(
    text: Style(foregroundRgb: RgbColor(76, 79, 105)),
    placeholder: Style(
      foregroundRgb: RgbColor(108, 111, 133),
      isItalic: true,
    ),
  );

  /// Defaults remain optimized for dark terminal backgrounds.
  static const TextAreaStyles defaults = dark;
}

/// Multi-line text editor bubble with grapheme-safe visual-row navigation.
final class TextAreaModel extends Model {
  TextAreaModel({
    this.value = '',
    this.cursorRow = 0,
    this.cursorCol = 0,
    this.scrollOffset = 0,
    this.maxHeight = 10,
    this.minHeight = 1,
    this.dynamicHeight = false,
    this.maxContentHeight = 0,
    this.width = 60,
    this.charLimit = 0,
    this.focused = true,
    this.placeholder = '',
    this.styles = TextAreaStyles.defaults,
  });

  TextAreaModel._copy({
    required this.value,
    required this.cursorRow,
    required this.cursorCol,
    required this.scrollOffset,
    required this.maxHeight,
    required this.minHeight,
    required this.dynamicHeight,
    required this.maxContentHeight,
    required this.width,
    required this.charLimit,
    required this.focused,
    required this.placeholder,
    required this.styles,
    List<String>? linesCache,
    List<_TextAreaVisualRow>? visualRowsCache,
  })  : _linesCache = linesCache,
        _visualRowsCache = visualRowsCache;

  final String value;
  final int cursorRow;
  final int cursorCol;
  final int scrollOffset;

  /// Maximum number of visual rows displayed at once.
  final int maxHeight;

  /// Minimum displayed height when [dynamicHeight] is enabled.
  final int minHeight;
  final bool dynamicHeight;

  /// Maximum accepted content height in soft-wrapped visual rows. Zero is unlimited.
  final int maxContentHeight;
  final int width;
  final int charLimit;
  final bool focused;
  final String placeholder;
  final TextAreaStyles styles;
  List<String>? _linesCache;
  List<_TextAreaVisualRow>? _visualRowsCache;

  List<String> get _logicalLines => _linesCache ??= value.split('\n');
  List<String> get lines => List<String>.of(_logicalLines);
  List<_TextAreaVisualRow> get _visualRows =>
      _visualRowsCache ??= List.unmodifiable(_buildVisualRows(value, width));
  int get visualLineCount => _visualRows.length;

  /// Zero-based logical line containing the cursor.
  int get cursorLine => cursorRow.clamp(0, _logicalLines.length - 1);

  /// Zero-based grapheme index within [cursorLine].
  int get cursorColumn =>
      cursorCol.clamp(0, _logicalLines[cursorLine].characters.length);

  int get visibleHeight {
    final contentHeight = visualLineCount;
    if (!dynamicHeight) {
      return maxHeight > 0 ? maxHeight : contentHeight;
    }
    final minimum = minHeight > 0 ? minHeight : 1;
    final maximum = maxHeight > 0
        ? maxHeight
        : (contentHeight < minimum ? minimum : contentHeight);
    return contentHeight.clamp(minimum, maximum < minimum ? minimum : maximum);
  }

  /// Top visual-row offset actually used by [view].
  int get visibleScrollOffset {
    final maximum = (visualLineCount - visibleHeight).clamp(0, visualLineCount);
    return scrollOffset.clamp(0, maximum);
  }

  int get cursorVisualRow => _cursorLocation.visualRow;
  int get cursorVisualColumn => _cursorLocation.cellColumn;
  double get scrollPercent {
    final maximum = (visualLineCount - visibleHeight).clamp(0, visualLineCount);
    return maximum == 0 ? 1.0 : scrollOffset.clamp(0, maximum) / maximum;
  }

  TextAreaModel moveToLineStart() =>
      copyWith(cursorRow: cursorLine, cursorCol: 0)._normalized();

  TextAreaModel moveToLineEnd() => copyWith(
        cursorRow: cursorLine,
        cursorCol: _logicalLines[cursorLine].characters.length,
      )._normalized();

  TextAreaModel moveToDocumentStart() =>
      copyWith(cursorRow: 0, cursorCol: 0)._normalized();

  TextAreaModel moveToDocumentEnd() {
    final lastLine = _logicalLines.length - 1;
    return copyWith(
      cursorRow: lastLine,
      cursorCol: _logicalLines[lastLine].characters.length,
    )._normalized();
  }

  TextAreaModel copyWith({
    String? value,
    int? cursorRow,
    int? cursorCol,
    int? scrollOffset,
    int? maxHeight,
    int? minHeight,
    bool? dynamicHeight,
    int? maxContentHeight,
    int? width,
    int? charLimit,
    bool? focused,
    String? placeholder,
    TextAreaStyles? styles,
  }) {
    final nextValue = value ?? this.value;
    final nextWidth = width ?? this.width;
    return TextAreaModel._copy(
      value: nextValue,
      cursorRow: cursorRow ?? this.cursorRow,
      cursorCol: cursorCol ?? this.cursorCol,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      maxHeight: maxHeight ?? this.maxHeight,
      minHeight: minHeight ?? this.minHeight,
      dynamicHeight: dynamicHeight ?? this.dynamicHeight,
      maxContentHeight: maxContentHeight ?? this.maxContentHeight,
      width: nextWidth,
      charLimit: charLimit ?? this.charLimit,
      focused: focused ?? this.focused,
      placeholder: placeholder ?? this.placeholder,
      styles: styles ?? this.styles,
      linesCache: nextValue == this.value ? _linesCache : null,
      visualRowsCache: nextValue == this.value && nextWidth == this.width
          ? _visualRowsCache
          : null,
    );
  }

  static int _wordStartBefore(List<String> chars, int pos) {
    var i = pos;
    while (i > 0 && chars[i - 1] == ' ') {
      i--;
    }
    while (i > 0 && chars[i - 1] != ' ') {
      i--;
    }
    return i;
  }

  bool _accepts(String candidate) {
    if (charLimit > 0 && candidate.characters.length > charLimit) return false;
    if (maxContentHeight > 0 &&
        _buildVisualRows(candidate, width).length > maxContentHeight) {
      return false;
    }
    return true;
  }

  TextAreaModel _normalized() {
    final currentLines = _logicalLines;
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final col = cursorCol.clamp(0, currentLines[row].characters.length);
    var next = copyWith(cursorRow: row, cursorCol: col);
    final location = next._cursorLocation;
    final maximum = (next.visualLineCount - next.visibleHeight)
        .clamp(0, next.visualLineCount);
    var offset = next.scrollOffset.clamp(0, maximum);
    if (location.visualRow < offset) {
      offset = location.visualRow;
    } else if (location.visualRow >= offset + next.visibleHeight) {
      offset = (location.visualRow - next.visibleHeight + 1).clamp(0, maximum);
    }
    next = next.copyWith(scrollOffset: offset);
    return next;
  }

  _TextAreaCursorLocation get _cursorLocation {
    final currentLines = _logicalLines;
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final lineChars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, lineChars.length);
    final rows = _visualRows;
    for (var visual = 0; visual < rows.length; visual++) {
      final candidate = rows[visual];
      if (candidate.logicalRow != row) continue;
      final isLineEnd =
          col == lineChars.length && candidate.end == lineChars.length;
      if ((col >= candidate.start && col < candidate.end) || isLineEnd) {
        var cellColumn = 0;
        for (var i = candidate.start; i < col; i++) {
          cellColumn += graphemeWidth(lineChars[i]);
        }
        return _TextAreaCursorLocation(visual, cellColumn);
      }
    }
    return const _TextAreaCursorLocation(0, 0);
  }

  TextAreaModel _insertText(String text) {
    final currentLines = List<String>.of(_logicalLines);
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final chars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, chars.length);
    final inserted = text.characters.toList();
    chars.insertAll(col, inserted);
    currentLines[row] = chars.join();
    final candidate = currentLines.join('\n');
    if (!_accepts(candidate)) return this;
    return copyWith(
      value: candidate,
      cursorRow: row,
      cursorCol: col + inserted.length,
    )._normalized();
  }

  TextAreaModel _insertNewline() {
    final currentLines = List<String>.of(_logicalLines);
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final chars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, chars.length);
    currentLines[row] = chars.sublist(0, col).join();
    currentLines.insert(row + 1, chars.sublist(col).join());
    final candidate = currentLines.join('\n');
    if (!_accepts(candidate)) return this;
    return copyWith(
      value: candidate,
      cursorRow: row + 1,
      cursorCol: 0,
    )._normalized();
  }

  TextAreaModel _deleteBackward() {
    final currentLines = List<String>.of(_logicalLines);
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final chars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, chars.length);
    if (col > 0) {
      chars.removeAt(col - 1);
      currentLines[row] = chars.join();
      return copyWith(
        value: currentLines.join('\n'),
        cursorCol: col - 1,
      )._normalized();
    }
    if (row == 0) return this;
    final previousLength = currentLines[row - 1].characters.length;
    currentLines[row - 1] += currentLines[row];
    currentLines.removeAt(row);
    return copyWith(
      value: currentLines.join('\n'),
      cursorRow: row - 1,
      cursorCol: previousLength,
    )._normalized();
  }

  TextAreaModel _deleteForward() {
    final currentLines = List<String>.of(_logicalLines);
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final chars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, chars.length);
    if (col < chars.length) {
      chars.removeAt(col);
      currentLines[row] = chars.join();
      return copyWith(value: currentLines.join('\n'))._normalized();
    }
    if (row >= currentLines.length - 1) return this;
    currentLines[row] += currentLines[row + 1];
    currentLines.removeAt(row + 1);
    return copyWith(value: currentLines.join('\n'))._normalized();
  }

  TextAreaModel _moveVisual(int delta) {
    final rows = _visualRows;
    final location = _cursorLocation;
    final target = (location.visualRow + delta).clamp(0, rows.length - 1);
    if (target == location.visualRow) return this;
    final targetRow = rows[target];
    final targetChars = _logicalLines[targetRow.logicalRow].characters.toList();
    var col = targetRow.start;
    var cells = 0;
    while (col < targetRow.end) {
      final next = graphemeWidth(targetChars[col]);
      if (cells + next > location.cellColumn) break;
      cells += next;
      col++;
    }
    return copyWith(
      cursorRow: targetRow.logicalRow,
      cursorCol: col,
    )._normalized();
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final currentLines = _logicalLines;
    final row = cursorRow.clamp(0, currentLines.length - 1);
    final lineChars = currentLines[row].characters.toList();
    final col = cursorCol.clamp(0, lineChars.length);

    switch (msg.key) {
      case 'backspace':
        return (_deleteBackward(), null);
      case 'delete':
        return (_deleteForward(), null);
      case 'enter':
        return (_insertNewline(), null);
      case 'up':
        return (_moveVisual(-1), null);
      case 'down':
        return (_moveVisual(1), null);
      case 'pgup':
        return (_moveVisual(-visibleHeight), null);
      case 'pgdown':
        return (_moveVisual(visibleHeight), null);
      case 'left':
        if (col > 0) {
          return (copyWith(cursorCol: col - 1)._normalized(), null);
        }
        if (row > 0) {
          return (
            copyWith(
              cursorRow: row - 1,
              cursorCol: currentLines[row - 1].characters.length,
            )._normalized(),
            null,
          );
        }
        return (this, null);
      case 'right':
        if (col < lineChars.length) {
          return (copyWith(cursorCol: col + 1)._normalized(), null);
        }
        if (row < currentLines.length - 1) {
          return (
            copyWith(cursorRow: row + 1, cursorCol: 0)._normalized(),
            null,
          );
        }
        return (this, null);
      case 'home':
      case 'ctrl+a':
        return (moveToLineStart(), null);
      case 'end':
      case 'ctrl+e':
        return (moveToLineEnd(), null);
      case 'ctrl+home':
        return (moveToDocumentStart(), null);
      case 'ctrl+end':
        return (moveToDocumentEnd(), null);
      case 'ctrl+w':
      case 'alt+backspace':
        final start = _wordStartBefore(lineChars, col);
        if (start == col) return (this, null);
        final mutableLines = List<String>.of(_logicalLines);
        mutableLines[row] = [
          ...lineChars.sublist(0, start),
          ...lineChars.sublist(col),
        ].join();
        return (
          copyWith(
            value: mutableLines.join('\n'),
            cursorCol: start,
          )._normalized(),
          null,
        );
      default:
        if (msg.key == 'ctrl+k') {
          final mutableLines = List<String>.of(_logicalLines);
          mutableLines[row] = lineChars.sublist(0, col).join();
          return (
            copyWith(value: mutableLines.join('\n'))._normalized(),
            null,
          );
        }
        if (msg.key == 'ctrl+u') {
          final mutableLines = List<String>.of(_logicalLines);
          mutableLines[row] = lineChars.sublist(col).join();
          return (
            copyWith(
              value: mutableLines.join('\n'),
              cursorCol: 0,
            )._normalized(),
            null,
          );
        }
        if (!focused) return (this, null);
        final key = msg.keyEvent;
        if (key.code == KeyCode.rune &&
            key.text.isNotEmpty &&
            key.modifiers.isEmpty) {
          return (_insertText(key.text), null);
        }
        return (this, null);
    }
  }

  @override
  View view() {
    if (value.isEmpty && !focused) {
      return newView(styles.placeholder.render(placeholder));
    }
    final rows = _visualRows;
    final start = visibleScrollOffset;
    final end = (start + visibleHeight).clamp(start, rows.length);
    final rendered = <String>[
      for (final row in rows.sublist(start, end)) styles.text.render(row.text),
    ];
    if (dynamicHeight) {
      while (rendered.length < visibleHeight) {
        rendered.add(styles.text.render(''));
      }
    }

    final result = newView(rendered.join('\n'));
    if (focused) {
      final location = _cursorLocation;
      final cursorY = location.visualRow - start;
      if (cursorY >= 0 && cursorY < visibleHeight) {
        result.cursor = Cursor(
          x: location.cellColumn,
          y: cursorY,
          shape: CursorShape.bar,
        );
      }
    }
    return result;
  }

  static List<_TextAreaVisualRow> _buildVisualRows(String value, int width) {
    final visualRows = <_TextAreaVisualRow>[];
    final logicalLines = value.split('\n');
    final available = width > 0 ? width : 0x7fffffff;
    for (var logical = 0; logical < logicalLines.length; logical++) {
      final chars = logicalLines[logical].characters.toList();
      if (chars.isEmpty) {
        visualRows.add(_TextAreaVisualRow('', logical, 0, 0));
        continue;
      }
      var start = 0;
      while (start < chars.length) {
        var end = start;
        var cells = 0;
        while (end < chars.length) {
          final next = graphemeWidth(chars[end]);
          if (end > start && cells + next > available) break;
          cells += next;
          end++;
          if (cells >= available) break;
        }
        visualRows.add(_TextAreaVisualRow(
          chars.sublist(start, end).join(),
          logical,
          start,
          end,
        ));
        start = end;
      }
    }
    return visualRows;
  }
}

final class _TextAreaVisualRow {
  const _TextAreaVisualRow(this.text, this.logicalRow, this.start, this.end);

  final String text;
  final int logicalRow;
  final int start;
  final int end;
}

final class _TextAreaCursorLocation {
  const _TextAreaCursorLocation(this.visualRow, this.cellColumn);

  final int visualRow;
  final int cellColumn;
}
