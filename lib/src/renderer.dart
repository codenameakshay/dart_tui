import 'dart:io';

import 'package:characters/characters.dart';

import 'ansi_state.dart';
import 'bubbles/style.dart' show getWidth;
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

  /// Imperatively hide or show the cursor.
  void setCursorVisibility(bool visible);

  /// Emit ANSI scroll sequences: positive [n] scrolls up, negative scrolls down.
  void scroll(int n, {bool up = true});
}

final class NilRenderer implements TeaRenderer {
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

final class _CursorRendererState {
  CursorShape? _shape;
  bool? _blink;
  int? _color;

  void apply(IOSink output, Cursor? cursor) {
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
    output.write('\x1b[$row;${column}H');
  }

  void reset(IOSink output) {
    if (_shape != null) output.write('\x1b[0 q');
    if (_color != null) output.write('\x1b]112\x07');
    _shape = null;
    _blink = null;
    _color = null;
  }
}

final class AnsiRenderer implements TeaRenderer {
  AnsiRenderer({
    required IOSink output,
    IOSink? logSink,
    required bool defaultAltScreen,
    required bool defaultHideCursor,
    MouseMode defaultMouseMode = MouseMode.none,
    bool defaultReportFocus = false,
  })  : _output = output,
        _logSink = logSink,
        _modes = TerminalModeState(
          defaultAltScreen: defaultAltScreen,
          defaultHideCursor: defaultHideCursor,
          defaultMouseMode: defaultMouseMode,
          defaultReportFocus: defaultReportFocus,
        );

  final IOSink _output;
  final IOSink? _logSink;
  final TerminalModeState _modes;
  List<String> _lastLines = const <String>[];
  String _lastContent = '';
  bool _hasRenderedFrame = false;
  bool _syncUpdates = false;
  bool _unicodeCoreEnabled = false;
  final _cursorState = _CursorRendererState();
  final _terminalViewState = TerminalViewState();

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
      _cursorState.apply(_output, view.cursor);
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

  @override
  void clearScreen() {
    _output.write('\x1b[H\x1b[2J');
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
  }

  @override
  void insertAbove(String line) {
    if (!_modes.altScreenEnabled) {
      _output.writeln(line);
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
    setUnicodeCore(false);
    _terminalViewState.reset(_output);
    _cursorState.reset(_output);
    _modes.reset(_output);
    _lastLines = const <String>[];
    _lastContent = '';
    _hasRenderedFrame = false;
    if (reset) {
      clearScreen();
    }
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
    if (n <= 0) return;
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
  CellRenderer({
    required IOSink output,
    IOSink? logSink,
    required bool defaultAltScreen,
    required bool defaultHideCursor,
    MouseMode defaultMouseMode = MouseMode.none,
    bool defaultReportFocus = false,
  })  : _output = output,
        _logSink = logSink,
        _modes = TerminalModeState(
          defaultAltScreen: defaultAltScreen,
          defaultHideCursor: defaultHideCursor,
          defaultMouseMode: defaultMouseMode,
          defaultReportFocus: defaultReportFocus,
        );

  final IOSink _output;
  final IOSink? _logSink;
  final TerminalModeState _modes;
  bool _unicodeCoreEnabled = false;

  List<List<_Cell>>? _lastGrid;
  String? _lastContent;
  final _cursorState = _CursorRendererState();
  final _terminalViewState = TerminalViewState();

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
      _cursorState.apply(_output, view.cursor);
      return; // identical frame — skip rebuild + diff walk
    }
    final nextGrid = _buildGrid(view.content);
    if (_lastGrid == null) {
      for (var row = 0; row < nextGrid.length; row++) {
        _output.write('\x1b[${row + 1};1H\x1b[K');
      }
    }
    _diffAndEmit(nextGrid);
    _lastGrid = nextGrid;
    _lastContent = view.content;
    _cursorState.apply(_output, view.cursor);
    _logSink?.writeln('--- cell frame ---\n${view.content}');
  }

  @override
  void clearScreen() {
    _output.write('\x1b[H\x1b[2J');
    _lastGrid = null;
    _lastContent = null;
  }

  @override
  void insertAbove(String line) {
    if (!_modes.altScreenEnabled) {
      _output.writeln(line);
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
    setUnicodeCore(false);
    _terminalViewState.reset(_output);
    _cursorState.reset(_output);
    _modes.reset(_output);
    _lastGrid = null;
    _lastContent = null;
    if (reset) clearScreen();
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
    if (n <= 0) return;
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
          for (final cluster in plainText.characters) {
            final attrs = state.sgrOpenSequence;
            final hyperlink = state.hyperlinkOpenSequence;
            cells.add(_Cell(cluster, attrs, hyperlink));
            for (var column = 1; column < graphemeWidth(cluster); column++) {
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

  /// Emit only the cells that differ from [_lastGrid].
  void _diffAndEmit(List<List<_Cell>> next) {
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
          _output.write('\x1b[${row + 1};${col + 1}H');
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
