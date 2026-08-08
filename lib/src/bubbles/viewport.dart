import 'package:characters/characters.dart';

import '../cmd.dart';
import '../grapheme_width.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

typedef ViewportGutterBuilder = String Function(ViewportGutterContext context);
typedef ViewportLineStyleBuilder = Style Function(int lineIndex);

final class ViewportGutterContext {
  const ViewportGutterContext({
    required this.index,
    required this.totalLines,
    required this.isSoftWrap,
  });

  final int index;
  final int totalLines;
  final bool isSoftWrap;

  @override
  bool operator ==(Object other) =>
      other is ViewportGutterContext &&
      other.index == index &&
      other.totalLines == totalLines &&
      other.isSoftWrap == isSoftWrap;

  @override
  int get hashCode => Object.hash(index, totalLines, isSoftWrap);
}

final class ViewportHighlight {
  const ViewportHighlight({
    required this.line,
    required this.start,
    required this.end,
  })  : assert(line >= 0),
        assert(start >= 0),
        assert(end > start);

  final int line;
  final int start;
  final int end;
}

/// Scrollable content pane with soft wrapping, gutters, and search highlights.
final class ViewportModel extends TeaModel {
  ViewportModel({
    this.content = '',
    this.width = 80,
    this.height = 24,
    this.yOffset = 0,
    this.xOffset = 0,
    this.softWrap = true,
    this.fillHeight = false,
    this.gutterBuilder,
    this.lineStyleBuilder,
    this.highlightStyle = const Style(isUnderline: true),
    this.selectedHighlightStyle = const Style(isReverse: true),
    this.mouseWheelEnabled = true,
    this.mouseWheelDelta = 3,
    this.horizontalStep = 6,
    List<ViewportHighlight> highlights = const <ViewportHighlight>[],
    this.selectedHighlightIndex = -1,
    this.searchQuery = '',
    this.searchCaseSensitive = false,
  })  : highlights = List<ViewportHighlight>.unmodifiable(highlights),
        _logicalLines = _splitLines(content),
        _rows = _computeRows(content, width, softWrap, gutterBuilder);

  final String content;
  final int width;
  final int height;
  final int yOffset;
  final int xOffset;
  final bool softWrap;
  final bool fillHeight;
  final ViewportGutterBuilder? gutterBuilder;
  final ViewportLineStyleBuilder? lineStyleBuilder;
  final Style highlightStyle;
  final Style selectedHighlightStyle;
  final bool mouseWheelEnabled;
  final int mouseWheelDelta;
  final int horizontalStep;
  final List<ViewportHighlight> highlights;
  final int selectedHighlightIndex;
  final String searchQuery;
  final bool searchCaseSensitive;

  final List<String> _logicalLines;
  final List<_ViewportRow> _rows;

  int get totalLines => _rows.length;
  int get logicalLineCount => _logicalLines.length;
  bool get atTop => yOffset <= 0;
  bool get atBottom => yOffset >= _maxYOffset;
  double get scrollPercent =>
      totalLines <= height ? 1.0 : yOffset.clamp(0, _maxYOffset) / _maxYOffset;
  double get horizontalScrollPercent =>
      _maxXOffset == 0 ? 1.0 : xOffset.clamp(0, _maxXOffset) / _maxXOffset;

  int get _visibleContentWidth =>
      (width - _gutterWidth(_logicalLines, gutterBuilder)).clamp(0, width);
  int get _maxYOffset => (totalLines - height).clamp(0, totalLines);
  int get _longestLineWidth {
    var longest = 0;
    for (final line in _logicalLines) {
      final lineWidth = textWidth(stripAnsi(line));
      if (lineWidth > longest) longest = lineWidth;
    }
    return longest;
  }

  int get _maxXOffset =>
      (_longestLineWidth - _visibleContentWidth).clamp(0, _longestLineWidth);

  ViewportModel _copy({
    String? content,
    int? width,
    int? height,
    int? yOffset,
    int? xOffset,
    bool? softWrap,
    bool? fillHeight,
    List<ViewportHighlight>? highlights,
    int? selectedHighlightIndex,
    String? searchQuery,
    bool? searchCaseSensitive,
  }) =>
      ViewportModel(
        content: content ?? this.content,
        width: width ?? this.width,
        height: height ?? this.height,
        yOffset: yOffset ?? this.yOffset,
        xOffset: xOffset ?? this.xOffset,
        softWrap: softWrap ?? this.softWrap,
        fillHeight: fillHeight ?? this.fillHeight,
        gutterBuilder: gutterBuilder,
        lineStyleBuilder: lineStyleBuilder,
        highlightStyle: highlightStyle,
        selectedHighlightStyle: selectedHighlightStyle,
        mouseWheelEnabled: mouseWheelEnabled,
        mouseWheelDelta: mouseWheelDelta,
        horizontalStep: horizontalStep,
        highlights: highlights ?? this.highlights,
        selectedHighlightIndex:
            selectedHighlightIndex ?? this.selectedHighlightIndex,
        searchQuery: searchQuery ?? this.searchQuery,
        searchCaseSensitive: searchCaseSensitive ?? this.searchCaseSensitive,
      );

  ViewportModel setContent(String newContent) => _copy(
        content: newContent,
        yOffset: 0,
        xOffset: 0,
        highlights: const <ViewportHighlight>[],
        selectedHighlightIndex: -1,
        searchQuery: '',
      );

  ViewportModel scrollTo(int line) =>
      _copy(yOffset: line.clamp(0, _maxYOffset));
  ViewportModel scrollBy(int delta) => scrollTo(yOffset + delta);
  ViewportModel scrollLeft(int columns) =>
      _withXOffset(xOffset - columns.clamp(0, _maxXOffset));
  ViewportModel scrollRight(int columns) =>
      _withXOffset(xOffset + columns.clamp(0, _maxXOffset));

  ViewportModel _withXOffset(int offset) {
    if (softWrap) return this;
    return _copy(xOffset: offset.clamp(0, _maxXOffset));
  }

  ViewportModel withHighlights(
    List<ViewportHighlight> ranges, {
    int selectedIndex = 0,
  }) {
    final valid = ranges
        .where((range) =>
            range.line < _logicalLines.length &&
            range.end <= _logicalLines[range.line].characters.length)
        .toList(growable: false);
    if (valid.isEmpty) return clearHighlights();
    final selected = selectedIndex.clamp(0, valid.length - 1);
    return _copy(
      highlights: valid,
      selectedHighlightIndex: selected,
      searchQuery: '',
    )._ensureSelectedVisible();
  }

  ViewportModel withSearch(
    String query, {
    bool caseSensitive = false,
  }) {
    if (query.isEmpty || content.isEmpty) return clearHighlights();
    final ranges = _literalMatches(_logicalLines, query, caseSensitive);
    if (ranges.isEmpty) {
      return _copy(
        highlights: const <ViewportHighlight>[],
        selectedHighlightIndex: -1,
        searchQuery: query,
        searchCaseSensitive: caseSensitive,
      );
    }
    return _copy(
      highlights: ranges,
      selectedHighlightIndex: 0,
      searchQuery: query,
      searchCaseSensitive: caseSensitive,
    )._ensureSelectedVisible();
  }

  ViewportModel clearHighlights() => _copy(
        highlights: const <ViewportHighlight>[],
        selectedHighlightIndex: -1,
        searchQuery: '',
      );

  ViewportModel highlightNext() {
    if (highlights.isEmpty) return this;
    final next = (selectedHighlightIndex + 1) % highlights.length;
    return _copy(selectedHighlightIndex: next)._ensureSelectedVisible();
  }

  ViewportModel highlightPrevious() {
    if (highlights.isEmpty) return this;
    final current = selectedHighlightIndex < 0 ? 0 : selectedHighlightIndex;
    final previous = (current - 1 + highlights.length) % highlights.length;
    return _copy(selectedHighlightIndex: previous)._ensureSelectedVisible();
  }

  ViewportModel _ensureSelectedVisible() {
    if (selectedHighlightIndex < 0 ||
        selectedHighlightIndex >= highlights.length) {
      return this;
    }
    final selected = highlights[selectedHighlightIndex];
    final rowIndex = _rows.indexWhere((row) =>
        row.logicalIndex == selected.line &&
        selected.start >= row.start &&
        selected.start < row.end);
    if (rowIndex < 0) return this;

    var nextY = yOffset.clamp(0, _maxYOffset);
    if (rowIndex < nextY) {
      nextY = rowIndex;
    } else if (rowIndex >= nextY + height) {
      nextY = (rowIndex - height + 1).clamp(0, _maxYOffset);
    }

    var nextX = xOffset.clamp(0, _maxXOffset);
    if (!softWrap && _visibleContentWidth > 0) {
      final lineChars = _logicalLines[selected.line].characters.toList();
      final startCell = textWidth(lineChars.take(selected.start).join());
      final endCell = textWidth(lineChars.take(selected.end).join());
      if (startCell < nextX) {
        nextX = startCell;
      } else if (endCell > nextX + _visibleContentWidth) {
        nextX = (endCell - _visibleContentWidth).clamp(0, _maxXOffset);
      }
    }
    return _copy(yOffset: nextY, xOffset: nextX);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is MouseWheelMsg && mouseWheelEnabled) {
      final horizontal =
          !softWrap && msg.mouse.modifiers.contains(KeyMod.shift);
      return switch (msg.mouse.button) {
        MouseButton.wheelUp => (
            horizontal
                ? scrollLeft(horizontalStep)
                : scrollBy(-mouseWheelDelta),
            null
          ),
        MouseButton.wheelDown => (
            horizontal
                ? scrollRight(horizontalStep)
                : scrollBy(mouseWheelDelta),
            null
          ),
        MouseButton.wheelLeft => (scrollLeft(horizontalStep), null),
        MouseButton.wheelRight => (scrollRight(horizontalStep), null),
        _ => (this, null),
      };
    }
    if (msg is! KeyMsg) return (this, null);
    return switch (msg.key) {
      'up' || 'k' => (scrollBy(-1), null),
      'down' || 'j' => (scrollBy(1), null),
      'pgup' || 'ctrl+b' => (scrollBy(-height), null),
      'pgdown' || 'ctrl+f' || 'space' => (scrollBy(height), null),
      'home' || 'g' => (scrollTo(0), null),
      'end' || 'G' => (scrollTo(totalLines), null),
      'left' => (scrollLeft(horizontalStep), null),
      'right' => (scrollRight(horizontalStep), null),
      _ => (this, null),
    };
  }

  @override
  View view() {
    if (width <= 0 || height <= 0) return newView('');
    final start = yOffset.clamp(0, _rows.length);
    final end = (start + height).clamp(start, _rows.length);
    final visible = _rows.sublist(start, end);
    final rendered = <String>[
      for (final row in visible) _renderRow(row),
    ];
    if (fillHeight) {
      while (rendered.length < height) {
        rendered.add(_renderFiller(rendered.length + start));
      }
    }
    return newView(rendered.join('\n'));
  }

  String _renderRow(_ViewportRow original) {
    final slice = softWrap
        ? _ViewportSlice(original.text, original.start, original.end)
        : _sliceCells(
            original.text,
            xOffset.clamp(0, _maxXOffset),
            _visibleContentWidth,
            original.start,
          );
    final lineStyle = lineStyleBuilder?.call(original.logicalIndex);
    final line = _applyHighlights(
      slice.text,
      original.logicalIndex,
      slice.start,
      lineStyle,
    );
    final gutter = gutterBuilder?.call(ViewportGutterContext(
          index: original.logicalIndex,
          totalLines: _logicalLines.length,
          isSoftWrap: original.isSoftWrap,
        )) ??
        '';
    return '$gutter$line';
  }

  String _renderFiller(int index) {
    final gutter = gutterBuilder?.call(ViewportGutterContext(
          index: index,
          totalLines: _logicalLines.length,
          isSoftWrap: false,
        )) ??
        '';
    return gutter;
  }

  String _applyHighlights(
    String text,
    int line,
    int start,
    Style? lineStyle,
  ) {
    final chars = text.characters.toList();
    if (chars.isEmpty || highlights.isEmpty) {
      return lineStyle?.render(text) ?? text;
    }
    final output = StringBuffer();
    Style? currentStyle;
    var run = StringBuffer();

    void flush() {
      if (run.isEmpty) return;
      final value = run.toString();
      final highlighted = currentStyle?.render(value) ?? value;
      output.write(lineStyle?.render(highlighted) ?? highlighted);
      run = StringBuffer();
    }

    for (var i = 0; i < chars.length; i++) {
      final absolute = start + i;
      Style? nextStyle;
      for (var h = 0; h < highlights.length; h++) {
        final range = highlights[h];
        if (range.line == line &&
            absolute >= range.start &&
            absolute < range.end) {
          nextStyle = h == selectedHighlightIndex
              ? selectedHighlightStyle
              : highlightStyle;
          break;
        }
      }
      if (!identical(nextStyle, currentStyle)) {
        flush();
        currentStyle = nextStyle;
      }
      run.write(chars[i]);
    }
    flush();
    return output.toString();
  }

  static List<String> _splitLines(String content) => content.split('\n');

  static List<_ViewportRow> _computeRows(
    String content,
    int width,
    bool softWrap,
    ViewportGutterBuilder? gutterBuilder,
  ) {
    final lines = _splitLines(content);
    final gutterWidth = _gutterWidth(lines, gutterBuilder);
    final available = (width - gutterWidth).clamp(1, width > 0 ? width : 1);
    final rows = <_ViewportRow>[];
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final chars = line.characters.toList();
      if (!softWrap || textWidth(stripAnsi(line)) <= available) {
        rows.add(_ViewportRow(line, lineIndex, 0, chars.length, false));
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
        rows.add(_ViewportRow(
          chars.sublist(start, end).join(),
          lineIndex,
          start,
          end,
          start > 0,
        ));
        start = end;
      }
      if (chars.isEmpty) {
        rows.add(_ViewportRow('', lineIndex, 0, 0, false));
      }
    }
    return List<_ViewportRow>.unmodifiable(rows);
  }

  static int _gutterWidth(
    List<String> lines,
    ViewportGutterBuilder? builder,
  ) {
    if (builder == null) return 0;
    var widest = 0;
    for (var i = 0; i < lines.length; i++) {
      for (final soft in const [false, true]) {
        final value = builder(ViewportGutterContext(
          index: i,
          totalLines: lines.length,
          isSoftWrap: soft,
        ));
        final valueWidth = textWidth(stripAnsi(value));
        if (valueWidth > widest) widest = valueWidth;
      }
    }
    return widest;
  }

  static List<ViewportHighlight> _literalMatches(
    List<String> lines,
    String query,
    bool caseSensitive,
  ) {
    final queryChars = query.characters
        .map((char) => caseSensitive ? char : char.toLowerCase())
        .toList();
    if (queryChars.isEmpty) return const <ViewportHighlight>[];
    final matches = <ViewportHighlight>[];
    for (var line = 0; line < lines.length; line++) {
      final chars = lines[line].characters.toList();
      final comparable = chars
          .map((char) => caseSensitive ? char : char.toLowerCase())
          .toList();
      var start = 0;
      while (start + queryChars.length <= comparable.length) {
        var matchesQuery = true;
        for (var offset = 0; offset < queryChars.length; offset++) {
          if (comparable[start + offset] != queryChars[offset]) {
            matchesQuery = false;
            break;
          }
        }
        if (matchesQuery) {
          matches.add(ViewportHighlight(
            line: line,
            start: start,
            end: start + queryChars.length,
          ));
          start += queryChars.length;
        } else {
          start++;
        }
      }
    }
    return matches;
  }

  static _ViewportSlice _sliceCells(
    String text,
    int offset,
    int width,
    int logicalStart,
  ) {
    if (width <= 0) return _ViewportSlice('', logicalStart, logicalStart);
    final chars = text.characters.toList();
    var cells = 0;
    var start = 0;
    while (
        start < chars.length && cells + graphemeWidth(chars[start]) <= offset) {
      cells += graphemeWidth(chars[start]);
      start++;
    }
    var end = start;
    var visibleCells = 0;
    while (end < chars.length) {
      final next = graphemeWidth(chars[end]);
      if (end > start && visibleCells + next > width) break;
      if (next > width && end == start) break;
      visibleCells += next;
      end++;
      if (visibleCells >= width) break;
    }
    return _ViewportSlice(
      chars.sublist(start, end).join(),
      logicalStart + start,
      logicalStart + end,
    );
  }
}

final class _ViewportRow {
  const _ViewportRow(
    this.text,
    this.logicalIndex,
    this.start,
    this.end,
    this.isSoftWrap,
  );

  final String text;
  final int logicalIndex;
  final int start;
  final int end;
  final bool isSoftWrap;
}

final class _ViewportSlice {
  const _ViewportSlice(this.text, this.start, this.end);

  final String text;
  final int start;
  final int end;
}
