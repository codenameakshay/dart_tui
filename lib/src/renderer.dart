import 'dart:io';

import 'package:characters/characters.dart';

import 'ansi_state.dart';
import 'bubbles/style.dart' show getWidth, truncate;
import 'grapheme_width.dart';
import 'terminal_control.dart';
import 'terminal_mode_state.dart';
import 'terminal_view_state.dart';
import 'view.dart';

abstract interface class TeaRenderer {
  void render(View view);
  void clearScreen();
  void insertAbove(String line);
  void setSyncUpdates(bool enabled);
  void setUnicodeCore(bool enabled);
  void release({bool reset = false});
  void restore(View view);
  void close();

  /// Imperatively enter or exit the alternate screen buffer.
  void setAltScreen(bool enabled);

  /// Whether the alternate screen buffer is currently active.
  bool get altScreenActive;

  /// Imperatively hide or show the cursor.
  void setCursorVisibility(bool visible);

  /// Emit ANSI scroll sequences: positive [n] scrolls up, negative scrolls down.
  /// Only in the alternate screen; inline frames ignore it.
  void scroll(int n, {bool up = true});
}

final class NilRenderer implements TeaRenderer {
  @override
  bool get altScreenActive => false;
  @override
  void clearScreen() {}
  @override
  void close() {}
  @override
  void insertAbove(String line) {}
  @override
  void setSyncUpdates(bool enabled) {}
  @override
  void setUnicodeCore(bool enabled) {}
  @override
  void release({bool reset = false}) {}
  @override
  void render(View view) {}
  @override
  void restore(View view) {}
  @override
  void setAltScreen(bool enabled) {}
  @override
  void setCursorVisibility(bool visible) {}
  @override
  void scroll(int n, {bool up = true}) {}
}

/// The 1-based terminal row to park the cursor on at exit: the view's last
/// row. A trailing newline ends the last line rather than adding an empty row,
/// and a last line wider than [columns] soft-wraps onto more rows.
int _parkRow(int rows, int Function(int row) widthOf, int columns) {
  var last = rows - 1;
  if (last > 0 && widthOf(last) == 0) last--;
  final width = widthOf(last);
  final wrappedRows =
      columns > 0 && width > columns ? (width - 1) ~/ columns : 0;
  return last + 1 + wrappedRows;
}

/// The physical column count when [output] is an interactive stdout, else 0.
int _stdoutColumns(IOSink output) =>
    identical(output, stdout) && stdout.hasTerminal
        ? stdout.terminalColumns
        : 0;

/// The physical row count when [output] is an interactive stdout, else 0.
int _stdoutLines(IOSink output) =>
    identical(output, stdout) && stdout.hasTerminal ? stdout.terminalLines : 0;

/// The last [maxRows] items of [rows] (all of them when [maxRows] <= 0).
List<T> _clipRows<T>(List<T> rows, int maxRows) =>
    maxRows > 0 && rows.length > maxRows
        ? rows.sublist(rows.length - maxRows)
        : rows;

/// An inline (normal-screen) frame: the rows it occupies below the row the
/// cursor was on when it first rendered (#18).
///
/// Every move is relative to the frame's top row (CR plus CSI n A / CSI n B),
/// so the frame never needs absolute rows or a cursor-position query and
/// never paints over the shell history above it. Rows below the frame are
/// created with newlines, which scroll the terminal when the frame reaches
/// the bottom of the screen.
///
/// Known limit: when the terminal is resized narrower, terminals that reflow
/// soft-wrapped rows can move the frame's top. The next redraw starts from
/// the tracked top, so some stale rows may stay above the redrawn frame.
final class _InlineFrame {
  /// The cursor row relative to the frame's top row.
  int row = 0;

  /// The number of rows the frame occupies on screen.
  int height = 0;

  /// The 1-based exit row, excluding a final empty line.
  int parkRow = 0;

  /// Moves to column 0 of [target], creating rows below the frame as needed.
  void moveTo(IOSink output, int target) {
    output.write('\r');
    // The cursor's own row always exists, even before the first write.
    final existing = height > 0 ? height : 1;
    final reachable = target < existing ? target : existing - 1;
    final delta = reachable - row;
    if (delta < 0) output.write('\x1b[${-delta}A');
    if (delta > 0) output.write('\x1b[${delta}B');
    for (var i = reachable; i < target; i++) {
      output.write('\r\n');
    }
    row = target;
    if (target >= height) height = target + 1;
  }

  /// Places the cursor at [r], [column] inside the frame.
  void place(IOSink output, int r, int column) {
    moveTo(output, r.clamp(0, height > 0 ? height - 1 : 0));
    if (column > 0) output.write('\x1b[${column + 1}G');
  }

  /// Erases the frame's rows from [from] down and forgets them.
  void eraseFrom(IOSink output, int from) {
    if (from >= height) return;
    moveTo(output, from);
    output.write('\x1b[J');
    height = from;
  }

  /// Starts a new, empty frame at the cursor's current row.
  void reset() {
    row = 0;
    height = 0;
    parkRow = 0;
  }
}

/// Erases [frame], writes [line] where it was (so it scrolls into history
/// like ordinary output), and starts a new frame on the row below it.
void _insertAboveInline(IOSink output, _InlineFrame frame, String line) {
  frame.eraseFrom(output, 0);
  frame.moveTo(output, 0);
  output.write(
      '${balanceAnsiState(line).replaceAll('\r\n', '\n').replaceAll('\n', '\r\n')}\r\n');
  frame.reset();
}

/// Moves to the 1-based [row] of an inline [frame] (none when 0) on exit.
/// Leaving the alternate screen restores the cursor to where it entered, and
/// Program writes no newline after an alt-screen exit, so step below the
/// inline frame here.
void _parkInline(
  IOSink output,
  _InlineFrame frame,
  int row, {
  required bool afterAltScreen,
}) {
  if (row <= 0 || frame.height == 0) return;
  frame.moveTo(output, row - 1);
  if (afterAltScreen) output.write('\r\n');
}

final class _CursorRendererState {
  CursorShape? _shape;
  bool? _blink;
  int? _color;
  (int, int)? _position;

  // Frame writes may move the physical cursor, so only unchanged-content
  // paths can reuse its last applied position. [place] positions the cursor
  // relative to an inline frame instead of with an absolute CSI row;colH.
  void apply(
    IOSink output,
    Cursor? cursor, {
    bool forcePosition = true,
    void Function(int row, int column)? place,
  }) {
    if (cursor == null) {
      reset(output);
      return;
    }

    if (cursor.shape != _shape || cursor.blink != _blink) {
      final style = switch (cursor.shape) {
        CursorShape.block => cursor.blink ? 1 : 2,
        CursorShape.underline => cursor.blink ? 3 : 4,
        CursorShape.bar => cursor.blink ? 5 : 6,
      };
      output.write('\x1b[$style q');
      _shape = cursor.shape;
      _blink = cursor.blink;
    }

    if (cursor.color != _color) {
      if (cursor.color == null) {
        output.write('\x1b]112\x07');
      } else {
        final hex =
            (cursor.color! & 0xffffff).toRadixString(16).padLeft(6, '0');
        output.write('\x1b]12;#$hex\x07');
      }
      _color = cursor.color;
    }

    final row = cursor.y.clamp(0, 0x7ffffffe) + 1;
    final column = cursor.x.clamp(0, 0x7ffffffe) + 1;
    if (forcePosition || _position != (row, column)) {
      if (place != null) {
        place(row - 1, column - 1);
      } else {
        output.write('\x1b[$row;${column}H');
      }
      _position = (row, column);
    }
  }

  void invalidatePosition() => _position = null;

  void reset(IOSink output) {
    if (_shape != null) output.write('\x1b[0 q');
    if (_color != null) output.write('\x1b]112\x07');
    _shape = null;
    _blink = null;
    _color = null;
    invalidatePosition();
  }
}

/// Renders views line by line.
///
/// Outside the alternate screen the view is drawn inline: the first frame
/// starts on the cursor's row, and every later move is relative to the
/// frame's top (see [_InlineFrame]). A frame taller than the terminal shows
/// its last rows, and lines wider than the terminal are truncated, so redraws
/// never push frame rows into scrollback.
final class AnsiRenderer implements TeaRenderer {
  /// [terminalColumns] and [terminalLines] report the physical terminal size
  /// used to fit inline frames; they default to stdout's size (0 = unknown,
  /// no fitting).
  AnsiRenderer({
    required IOSink output,
    IOSink? logSink,
    required bool defaultAltScreen,
    required bool defaultHideCursor,
    MouseMode defaultMouseMode = MouseMode.none,
    bool defaultReportFocus = false,
    int Function()? terminalColumns,
    int Function()? terminalLines,
  })  : _output = output,
        _logSink = logSink,
        _terminalColumns = terminalColumns ?? (() => _stdoutColumns(output)),
        _terminalLines = terminalLines ?? (() => _stdoutLines(output)),
        _modes = TerminalModeState(
          defaultAltScreen: defaultAltScreen,
          defaultHideCursor: defaultHideCursor,
          defaultMouseMode: defaultMouseMode,
          defaultReportFocus: defaultReportFocus,
        );

  final IOSink _output;
  final IOSink? _logSink;
  final int Function() _terminalColumns;
  final int Function() _terminalLines;
  final TerminalModeState _modes;
  List<String> _lastLines = const <String>[];
  String _lastContent = '';
  bool _hasRenderedFrame = false;
  bool _syncUpdates = false;
  bool _unicodeCoreEnabled = false;
  final _cursorState = _CursorRendererState();
  final _terminalViewState = TerminalViewState();
  final _frame = _InlineFrame();
  int _clippedRows = 0;

  void Function(int, int)? get _placeCursor => _modes.altScreenEnabled
      ? null
      : (row, column) => _frame.place(_output, row - _clippedRows, column);

  @override
  void render(View view) {
    final wantsAlt = _modes.effectiveAltScreen(view);
    _terminalViewState.beforeScreenChange(_output, wantsAlt);
    if (_modes.apply(_output, view)) {
      _lastLines = const <String>[];
      _lastContent = '';
      _hasRenderedFrame = false;
    }
    _terminalViewState.apply(_output, view, altScreen: wantsAlt);
    if (view.windowTitle.isNotEmpty) {
      _output.write(windowTitleSequence(view.windowTitle));
    }
    if (_hasRenderedFrame && view.content == _lastContent) {
      _cursorState.apply(
        _output,
        view.cursor,
        forcePosition: false,
        place: _placeCursor,
      );
      return;
    }
    if (!_modes.altScreenEnabled) {
      _renderInline(view);
      return;
    }
    final nextLines = view.content.split('\n');

    if (_syncUpdates) _output.write('\x1b[?2026h');
    final maxRows = nextLines.length > _lastLines.length
        ? nextLines.length
        : _lastLines.length;
    final firstFrame = !_hasRenderedFrame;
    for (var row = 0; row < maxRows; row++) {
      final next = row < nextLines.length ? nextLines[row] : '';
      final prev = row < _lastLines.length ? _lastLines[row] : '';
      if (!firstFrame && next == prev) continue;
      _output.write('\x1b[${row + 1};1H');
      if (firstFrame) _output.write('\x1b[K');
      _output.write(next);
      // Only erase to end of line when the new line is *narrower* than the old
      // one — the sole case where stale cells from the previous frame remain
      // (the columns between the two widths). Erasing unconditionally lands the
      // EL on the pending-wrap last column of a full-width line and wipes the
      // just-painted cell, which loses the right edge and flickers it on every
      // redraw. Widths are compared visibly (SGR codes ignored, wide chars = 2).
      if (!firstFrame && getWidth(next) < getWidth(prev)) {
        _output.write('\x1b[K');
      }
    }
    if (_syncUpdates) _output.write('\x1b[?2026l');

    _lastLines = nextLines;
    _lastContent = view.content;
    _hasRenderedFrame = true;
    _cursorState.apply(_output, view.cursor);
    _logSink?.writeln('--- frame (diff) ---\n${view.content}');
  }

  void _renderInline(View view) {
    final columns = _terminalColumns();
    final all = balanceAnsiState(view.content).split('\n');
    final clipped = _clipRows(all, _terminalLines());
    final nextLines = columns > 0
        ? [for (final line in clipped) truncate(line, columns)]
        : clipped;
    _clippedRows = all.length - nextLines.length;
    final full = !_hasRenderedFrame;
    final prevLines = full ? const <String>[] : _lastLines;

    if (_syncUpdates) _output.write('\x1b[?2026h');
    for (var row = 0; row < nextLines.length; row++) {
      final next = nextLines[row];
      final prev = row < prevLines.length ? prevLines[row] : null;
      if (next == prev) continue;
      _frame.moveTo(_output, row);
      // A repainted or new row may hold stale cells; clear it before writing
      // (erasing after would wipe the last column of a full-width line, #7).
      if (prev == null) _output.write('\x1b[K');
      _output.write(next);
      if (prev != null && getWidth(next) < getWidth(prev)) {
        _output.write('\x1b[K');
      }
    }
    _frame.eraseFrom(_output, nextLines.length);
    if (_syncUpdates) _output.write('\x1b[?2026l');

    _frame.parkRow =
        _parkRow(nextLines.length, (r) => getWidth(nextLines[r]), 0);
    _lastLines = nextLines;
    _lastContent = view.content;
    _hasRenderedFrame = true;
    _cursorState.apply(_output, view.cursor, place: _placeCursor);
    _logSink?.writeln('--- frame (inline) ---\n${view.content}');
  }

  @override
  void setSyncUpdates(bool enabled) {
    _syncUpdates = enabled;
  }

  @override
  void setUnicodeCore(bool enabled) {
    if (enabled == _unicodeCoreEnabled) return;
    _output.write(enabled ? '\x1b[?2027h' : '\x1b[?2027l');
    _unicodeCoreEnabled = enabled;
  }

  /// Clears the alternate screen, or erases only the inline frame.
  @override
  void clearScreen() {
    if (_modes.altScreenEnabled) {
      _output.write('\x1b[H\x1b[2J');
    } else {
      _frame.eraseFrom(_output, 0);
    }
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
  }

  @override
  void insertAbove(String line) {
    if (!_modes.altScreenEnabled) {
      _insertAboveInline(_output, _frame, line);
      _cursorState.invalidatePosition();
      _lastLines = const <String>[];
      _lastContent = '';
      _hasRenderedFrame = false;
      return;
    }
    // In alt-screen: save cursor, scroll up to create space, write at top, restore
    _output.write('\x1b[s'); // save cursor position
    _output.write('\x1b[1;1H'); // move to top-left
    _output.write('\x1b[S'); // scroll up one line (creates blank row at bottom)
    _output.write('\x1b[1;1H'); // back to top-left
    // Clear the row *before* writing the line. Erasing after would land the EL
    // on the pending-wrap last column of a full-width line and wipe it (#7);
    // erasing first still removes any content the scroll shifted into this row.
    _output.write('\x1b[K'); // clear to end of line
    _output.write(line);
    _output.write('\x1b[u'); // restore cursor position
    _hasRenderedFrame = false; // invalidate diff cache
  }

  @override
  void release({bool reset = false}) {
    // Park on the view's last row, not the last changed one, so the newline
    // Program writes on exit puts the shell prompt below the view. Inline
    // lines are truncated to the terminal width, so they never soft-wrap.
    final lines = _lastLines;
    final inline = !_modes.altScreenEnabled;
    final parkRow = reset
        ? 0
        : inline && _hasRenderedFrame
            ? _parkRow(lines.length, (r) => getWidth(lines[r]), 0)
            : _frame.parkRow;
    setUnicodeCore(false);
    _terminalViewState.reset(_output);
    _cursorState.reset(_output);
    _modes.reset(_output);
    _parkInline(_output, _frame, parkRow, afterAltScreen: !inline);
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
    if (reset) {
      // Erase only an inline frame (including one saved under the alt
      // screen), never the shell history above it. A pure alt-screen program
      // keeps its existing clear.
      if (inline || _frame.height > 0) {
        _frame.eraseFrom(_output, 0);
      } else {
        _output.write('\x1b[H\x1b[2J');
      }
    }
    _frame.reset();
  }

  @override
  void restore(View view) {
    render(view);
  }

  @override
  void close() {
    release();
  }

  @override
  bool get altScreenActive => _modes.altScreenEnabled;

  @override
  void setAltScreen(bool enabled) {
    _terminalViewState.beforeScreenChange(_output, enabled);
    if (!_modes.setAltScreen(_output, enabled)) return;
    _terminalViewState.restoreKeyboard(_output, enabled);
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
  }

  @override
  void setCursorVisibility(bool visible) =>
      _modes.setCursorVisibility(_output, visible);

  @override
  void scroll(int n, {bool up = true}) {
    // Inline, scrolling the whole terminal would move shell history and the
    // frame's anchor, so it only applies in the alternate screen.
    if (n <= 0 || !_modes.altScreenEnabled) return;
    // ESC[nS = scroll up n lines; ESC[nT = scroll down n lines
    _output.write(up ? '\x1b[${n}S' : '\x1b[${n}T');
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
  }
}

// ─── Cell-level diff renderer ──────────────────────────────────────────────

/// A single terminal cell with its active rendering state.
final class _Cell {
  const _Cell(this.char, this.attrs, [this.hyperlink = ''])
      : isContinuation = false;

  const _Cell.continuation(this.attrs, [this.hyperlink = ''])
      : char = '',
        isContinuation = true;

  final String char; // one grapheme cluster (may be multi-byte)
  final String
      attrs; // the CSI SGR sequence(s) active at this cell, e.g. '\x1b[1;32m'
  final String hyperlink; // active OSC 8 opening sequence
  final bool isContinuation;

  @override
  bool operator ==(Object other) =>
      other is _Cell &&
      other.char == char &&
      other.attrs == attrs &&
      other.hyperlink == hyperlink &&
      other.isContinuation == isContinuation;

  @override
  int get hashCode => Object.hash(char, attrs, hyperlink, isContinuation);
}

/// Renderer that diffs at the individual cell level, emitting precise
/// cursor-move + character-write sequences only for changed cells.
///
/// This produces less flicker than the line-level [AnsiRenderer] on terminals
/// that do not support synchronized updates (?2026).
///
/// Activate via [withCellRenderer] program option.
final class CellRenderer implements TeaRenderer {
  /// See [AnsiRenderer.new] for [terminalColumns], [terminalLines] and inline
  /// rendering outside the alternate screen.
  CellRenderer({
    required IOSink output,
    IOSink? logSink,
    required bool defaultAltScreen,
    required bool defaultHideCursor,
    MouseMode defaultMouseMode = MouseMode.none,
    bool defaultReportFocus = false,
    int Function()? terminalColumns,
    int Function()? terminalLines,
  })  : _output = output,
        _logSink = logSink,
        _terminalColumns = terminalColumns ?? (() => _stdoutColumns(output)),
        _terminalLines = terminalLines ?? (() => _stdoutLines(output)),
        _modes = TerminalModeState(
          defaultAltScreen: defaultAltScreen,
          defaultHideCursor: defaultHideCursor,
          defaultMouseMode: defaultMouseMode,
          defaultReportFocus: defaultReportFocus,
        );

  final IOSink _output;
  final IOSink? _logSink;
  final int Function() _terminalColumns;
  final int Function() _terminalLines;
  final TerminalModeState _modes;
  bool _unicodeCoreEnabled = false;

  List<List<_Cell>>? _lastGrid;
  String? _lastContent;
  final _cursorState = _CursorRendererState();
  final _terminalViewState = TerminalViewState();
  final _frame = _InlineFrame();
  int _clippedRows = 0;

  void Function(int, int)? get _placeCursor => _modes.altScreenEnabled
      ? null
      : (row, column) => _frame.place(_output, row - _clippedRows, column);

  @override
  void render(View view) {
    final wantsAlt = _modes.effectiveAltScreen(view);
    _terminalViewState.beforeScreenChange(_output, wantsAlt);
    if (_modes.apply(_output, view)) {
      _lastGrid = null;
      _lastContent = null;
    }
    _terminalViewState.apply(_output, view, altScreen: wantsAlt);
    if (view.windowTitle.isNotEmpty) {
      _output.write(windowTitleSequence(view.windowTitle));
    }
    if (_lastGrid != null && _lastContent == view.content) {
      _cursorState.apply(
        _output,
        view.cursor,
        forcePosition: false,
        place: _placeCursor,
      );
      return; // identical frame — skip rebuild + diff walk
    }
    final nextGrid = _buildGrid(view.content);
    if (!_modes.altScreenEnabled) {
      _renderInline(view, nextGrid);
      return;
    }
    if (_lastGrid == null) {
      for (var row = 0; row < nextGrid.length; row++) {
        _output.write('\x1b[${row + 1};1H\x1b[K');
      }
    }
    _diffAndEmit(
      nextGrid,
      (row, col) => _output.write('\x1b[${row + 1};${col + 1}H'),
    );
    _lastGrid = nextGrid;
    _lastContent = view.content;
    _cursorState.apply(_output, view.cursor);
    _logSink?.writeln('--- cell frame ---\n${view.content}');
  }

  void _renderInline(View view, List<List<_Cell>> built) {
    final columns = _terminalColumns();
    final clipped = _clipRows(built, _terminalLines());
    final grid = columns > 0
        ? [for (final row in clipped) _truncateCells(row, columns)]
        : clipped;
    _clippedRows = built.length - grid.length;
    _frame.eraseFrom(_output, grid.length);
    final prev = _lastGrid;
    // Erased rows must not be diffed (or recreated).
    if (prev != null && prev.length > grid.length) {
      _lastGrid = prev.sublist(0, grid.length);
    }
    // Clear rows that may hold stale cells before the diff writes (with no
    // SGR active, so the erase is not colored): every row when the frame is
    // new or its diff state was lost, else only rows the frame grows into.
    for (var row = prev == null ? 0 : _frame.height; row < grid.length; row++) {
      _frame.moveTo(_output, row);
      _output.write('\x1b[K');
    }
    _diffAndEmit(grid, (row, col) {
      _frame.moveTo(_output, row);
      if (col > 0) _output.write('\x1b[${col + 1}G');
    });
    _frame.parkRow = _parkRow(grid.length, (r) => grid[r].length, 0);
    _lastGrid = grid;
    _lastContent = view.content;
    _cursorState.apply(_output, view.cursor, place: _placeCursor);
    _logSink?.writeln('--- cell frame (inline) ---\n${view.content}');
  }

  /// Clears the alternate screen, or erases only the inline frame.
  @override
  void clearScreen() {
    if (_modes.altScreenEnabled) {
      _output.write('\x1b[H\x1b[2J');
    } else {
      _frame.eraseFrom(_output, 0);
    }
    _lastGrid = null;
    _lastContent = null;
  }

  @override
  void insertAbove(String line) {
    if (!_modes.altScreenEnabled) {
      _insertAboveInline(_output, _frame, line);
      _cursorState.invalidatePosition();
      _lastGrid = null;
      _lastContent = null;
      return;
    }
    _output.write('\x1b[s');
    _output.write('\x1b[1;1H');
    _output.write('\x1b[S');
    _output.write('\x1b[1;1H');
    // Clear the row before writing so a full-width line keeps its last column
    // (see AnsiRenderer.insertAbove / #7).
    _output.write('\x1b[K');
    _output.write(line);
    _output.write('\x1b[u');
    _lastGrid = null;
    _lastContent = null;
  }

  @override
  void release({bool reset = false}) {
    // See AnsiRenderer.release.
    final grid = _lastGrid;
    final inline = !_modes.altScreenEnabled;
    final parkRow = reset
        ? 0
        : inline && grid != null
            ? _parkRow(grid.length, (r) => grid[r].length, 0)
            : _frame.parkRow;
    setUnicodeCore(false);
    _terminalViewState.reset(_output);
    _cursorState.reset(_output);
    _modes.reset(_output);
    _parkInline(_output, _frame, parkRow, afterAltScreen: !inline);
    _lastGrid = null;
    _lastContent = null;
    if (reset) {
      // Erase only an inline frame (including one saved under the alt
      // screen), never the shell history above it. A pure alt-screen program
      // keeps its existing clear.
      if (inline || _frame.height > 0) {
        _frame.eraseFrom(_output, 0);
      } else {
        _output.write('\x1b[H\x1b[2J');
      }
    }
    _frame.reset();
  }

  @override
  void restore(View view) => render(view);

  @override
  void close() => release();

  @override
  void setSyncUpdates(bool enabled) {} // cell renderer handles its own sync

  @override
  void setUnicodeCore(bool enabled) {
    if (enabled == _unicodeCoreEnabled) return;
    _output.write(enabled ? '\x1b[?2027h' : '\x1b[?2027l');
    _unicodeCoreEnabled = enabled;
  }

  @override
  bool get altScreenActive => _modes.altScreenEnabled;

  @override
  void setAltScreen(bool enabled) {
    _terminalViewState.beforeScreenChange(_output, enabled);
    if (!_modes.setAltScreen(_output, enabled)) return;
    _terminalViewState.restoreKeyboard(_output, enabled);
    _lastGrid = null;
    _lastContent = null;
  }

  @override
  void setCursorVisibility(bool visible) =>
      _modes.setCursorVisibility(_output, visible);

  @override
  void scroll(int n, {bool up = true}) {
    // See AnsiRenderer.scroll: inline scrolling is a no-op.
    if (n <= 0 || !_modes.altScreenEnabled) return;
    _output.write(up ? '\x1b[${n}S' : '\x1b[${n}T');
    _lastGrid = null;
    _lastContent = null;
  }

  // ── Grid building ──────────────────────────────────────────────────────────

  /// Parse [content] into a 2-D grid of [_Cell]s.
  /// Rows are separated by '\n'. Within each row, we walk grapheme clusters
  /// while tracking the active SGR and OSC 8 state.
  List<List<_Cell>> _buildGrid(String content) {
    final lines = content.split('\n');
    final grid = <List<_Cell>>[];
    for (final line in lines) {
      final cells = <_Cell>[];
      final state = AnsiStateTracker();
      var i = 0;
      final raw = line; // raw string with ANSI codes
      while (i < raw.length) {
        if (raw[i] == '\x1b') {
          // Consume the escape sequence
          final seq = _consumeEscape(raw, i);
          state.accept(seq.raw);
          i += seq.length;
        } else {
          final nextEscape = raw.indexOf('\x1b', i);
          final plainEnd = nextEscape < 0 ? raw.length : nextEscape;
          final plainText = raw.substring(i, plainEnd);
          final attrs = state.sgrOpenSequence;
          final hyperlink = state.hyperlinkOpenSequence;
          for (final cluster in plainText.characters) {
            cells.add(_Cell(cluster, attrs, hyperlink));
            final width = graphemeWidth(cluster);
            for (var column = 1; column < width; column++) {
              cells.add(_Cell.continuation(attrs, hyperlink));
            }
          }
          i = plainEnd;
        }
      }
      grid.add(cells);
    }
    return grid;
  }

  /// Emit only the cells that differ from [_lastGrid], positioning the cursor
  /// with [move] (0-based row and column).
  void _diffAndEmit(
    List<List<_Cell>> next,
    void Function(int row, int col) move,
  ) {
    final prev = _lastGrid;
    final rows =
        next.length > (prev?.length ?? 0) ? next.length : (prev?.length ?? 0);
    var lastRow = -1;
    var lastCol = -1;
    var lastAttrs = '';
    var lastHyperlink = '';

    for (var row = 0; row < rows; row++) {
      final nextRow = row < next.length ? next[row] : const <_Cell>[];
      final prevRow =
          (prev != null && row < prev.length) ? prev[row] : const <_Cell>[];
      final cols =
          nextRow.length > prevRow.length ? nextRow.length : prevRow.length;

      for (var col = 0; col < cols; col++) {
        final nextCell =
            col < nextRow.length ? nextRow[col] : const _Cell(' ', '');
        final prevCell =
            col < prevRow.length ? prevRow[col] : const _Cell(' ', '');

        if (nextCell == prevCell) continue;

        // A continuation cell is occupied by the wide grapheme emitted from
        // the preceding terminal column. It participates in equality so that
        // stale content is cleared when a wide glyph disappears, but it must
        // never be written independently.
        if (nextCell.isContinuation) continue;

        // Move cursor if needed
        if (lastRow != row || lastCol != col) {
          move(row, col);
          lastRow = row;
          lastCol = col;
        }

        if (nextCell.hyperlink != lastHyperlink) {
          if (lastHyperlink.isNotEmpty) _output.write('\x1b]8;;\x1b\\');
          if (nextCell.hyperlink.isNotEmpty) {
            _output.write(nextCell.hyperlink);
          }
          lastHyperlink = nextCell.hyperlink;
        }

        // Apply attrs if changed
        if (nextCell.attrs != lastAttrs) {
          if (nextCell.attrs.isEmpty) {
            _output.write('\x1b[0m');
          } else {
            _output.write(nextCell.attrs);
          }
          lastAttrs = nextCell.attrs;
        }

        _output.write(nextCell.char);
        lastCol += graphemeWidth(nextCell.char);
      }
    }

    // Reset SGR if we wrote anything with attrs
    if (lastAttrs.isNotEmpty) {
      _output.write('\x1b[0m');
    }
    if (lastHyperlink.isNotEmpty) {
      _output.write('\x1b]8;;\x1b\\');
    }
  }
}

/// The first [columns] cells of [row], dropping a wide grapheme that would
/// straddle the right edge.
List<_Cell> _truncateCells(List<_Cell> row, int columns) {
  if (row.length <= columns) return row;
  var end = columns;
  while (end > 0 && row[end].isContinuation) {
    end--;
  }
  return row.sublist(0, end);
}

// ── Escape sequence parser helper ─────────────────────────────────────────────

final class _EscSeq {
  const _EscSeq({required this.raw, required this.length});
  final String raw;
  final int length;
}

/// Consume one escape sequence starting at [start] in [s].
/// Returns the raw sequence and its length.
_EscSeq _consumeEscape(String s, int start) {
  // Expect s[start] == '\x1b'
  if (start + 1 >= s.length) {
    return const _EscSeq(raw: '\x1b', length: 1);
  }

  final next = s[start + 1];
  if (next == '[') {
    // CSI sequence: \x1b[ ... final_byte (@ through ~, i.e. 0x40-0x7E)
    var i = start + 2;
    while (i < s.length && (s.codeUnitAt(i) < 0x40 || s.codeUnitAt(i) > 0x7E)) {
      i++;
    }
    if (i < s.length) i++; // include the final byte
    final raw = s.substring(start, i);
    return _EscSeq(raw: raw, length: i - start);
  } else if (next == ']' || next == 'P') {
    // OSC strings end with BEL or ST; DCS strings end with ST. Consume the
    // complete two-byte ST so its trailing backslash cannot become content.
    final isOsc = next == ']';
    var i = start + 2;
    while (i < s.length) {
      if (isOsc && s[i] == '\x07') {
        i++;
        break;
      }
      if (s[i] == '\x1b' && i + 1 < s.length && s[i + 1] == '\\') {
        i += 2;
        break;
      }
      i++;
    }
    return _EscSeq(raw: s.substring(start, i), length: i - start);
  } else {
    // Single-char escape (e.g. \x1b7, \x1b8)
    return _EscSeq(raw: s.substring(start, start + 2), length: 2);
  }
}
