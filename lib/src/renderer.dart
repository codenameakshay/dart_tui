import 'dart:io';

import 'package:characters/characters.dart';

import 'view.dart';

abstract interface class TeaRenderer {
  void render(View view);
  void clearScreen();
  void insertAbove(String line);
  void setSyncUpdates(bool enabled);
  void release({bool reset = false});
  void restore(View view);
  void close();
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
  void release({bool reset = false}) {}

  @override
  void render(View view) {}

  @override
  void restore(View view) {}
}

final class AnsiRenderer implements TeaRenderer {
  AnsiRenderer({
    required IOSink output,
    IOSink? logSink,
    required bool defaultAltScreen,
    required bool defaultHideCursor,
  })  : _output = output,
        _logSink = logSink,
        _defaultAltScreen = defaultAltScreen,
        _defaultHideCursor = defaultHideCursor;

  final IOSink _output;
  final IOSink? _logSink;
  final bool _defaultAltScreen;
  final bool _defaultHideCursor;

  bool _altScreenEnabled = false;
  bool _cursorHidden = false;
  bool _focusReportingEnabled = false;
  bool _bracketedPasteEnabled = false;
  MouseMode _mouseMode = MouseMode.none;
  List<String> _lastLines = const <String>[];
  bool _hasRenderedFrame = false;
  bool _syncUpdates = false;

  @override
  void render(View view) {
    _applyModes(view);
    if (view.windowTitle.isNotEmpty) {
      _output.write('\x1b]0;${view.windowTitle}\x07');
    }
    final nextLines = view.content.split('\n');
    if (_hasRenderedFrame && _linesEqual(nextLines, _lastLines)) {
      return;
    }

    if (_syncUpdates) _output.write('\x1b[?2026h');
    final maxRows =
        nextLines.length > _lastLines.length ? nextLines.length : _lastLines.length;
    for (var row = 0; row < maxRows; row++) {
      final next = row < nextLines.length ? nextLines[row] : '';
      final prev = row < _lastLines.length ? _lastLines[row] : '';
      if (next == prev) continue;
      _output.write('\x1b[${row + 1};1H');
      _output.write(next);
      _output.write('\x1b[K');
    }
    if (_syncUpdates) _output.write('\x1b[?2026l');

    _lastLines = List<String>.from(nextLines);
    _hasRenderedFrame = true;
    _logSink?.writeln('--- frame (diff) ---\n${view.content}');
  }

  @override
  void setSyncUpdates(bool enabled) {
    _syncUpdates = enabled;
  }

  @override
  void clearScreen() {
    _output.write('\x1b[H\x1b[2J');
    _lastLines = const <String>[];
    _hasRenderedFrame = false;
  }

  @override
  void insertAbove(String line) {
    if (!_altScreenEnabled) {
      _output.writeln(line);
      return;
    }
    // In alt-screen: save cursor, scroll up to create space, write at top, restore
    _output.write('\x1b[s');      // save cursor position
    _output.write('\x1b[1;1H');   // move to top-left
    _output.write('\x1b[S');      // scroll up one line (creates blank row at bottom)
    _output.write('\x1b[1;1H');   // back to top-left
    _output.write(line);
    _output.write('\x1b[K');      // clear to end of line
    _output.write('\x1b[u');      // restore cursor position
    _hasRenderedFrame = false;    // invalidate diff cache
  }

  @override
  void release({bool reset = false}) {
    _output.write('\x1b[?25h');
    _output.write('\x1b[?1049l');
    _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
    _output.write('\x1b[?1004l');
    _output.write('\x1b[?2004l');
    _cursorHidden = false;
    _altScreenEnabled = false;
    _focusReportingEnabled = false;
    _bracketedPasteEnabled = false;
    _mouseMode = MouseMode.none;
    _lastLines = const <String>[];
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

  bool _linesEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applyModes(View v) {
    final wantsAlt = v.altScreen || _defaultAltScreen;
    if (wantsAlt != _altScreenEnabled) {
      _output.write(wantsAlt ? '\x1b[?1049h' : '\x1b[?1049l');
      _altScreenEnabled = wantsAlt;
    }

    final wantsHiddenCursor = v.cursor == null && _defaultHideCursor;
    if (wantsHiddenCursor != _cursorHidden) {
      _output.write(wantsHiddenCursor ? '\x1b[?25l' : '\x1b[?25h');
      _cursorHidden = wantsHiddenCursor;
    }

    if (v.reportFocus != _focusReportingEnabled) {
      _output.write(v.reportFocus ? '\x1b[?1004h' : '\x1b[?1004l');
      _focusReportingEnabled = v.reportFocus;
    }

    final wantsBracketedPaste = !v.disableBracketedPasteMode;
    if (wantsBracketedPaste != _bracketedPasteEnabled) {
      _output.write(wantsBracketedPaste ? '\x1b[?2004h' : '\x1b[?2004l');
      _bracketedPasteEnabled = wantsBracketedPaste;
    }

    if (v.mouseMode != _mouseMode) {
      _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
      switch (v.mouseMode) {
        case MouseMode.none:
          break;
        case MouseMode.cellMotion:
          _output.write('\x1b[?1002h\x1b[?1006h');
          break;
        case MouseMode.allMotion:
          _output.write('\x1b[?1003h\x1b[?1006h');
          break;
      }
      _mouseMode = v.mouseMode;
    }
  }
}

// ─── Cell-level diff renderer ──────────────────────────────────────────────

/// A single terminal cell: one grapheme cluster plus the active SGR state.
final class _Cell {
  const _Cell(this.char, this.attrs);
  final String char;   // one grapheme cluster (may be multi-byte)
  final String attrs;  // the CSI SGR sequence(s) active at this cell, e.g. '\x1b[1;32m'

  @override
  bool operator ==(Object other) =>
      other is _Cell && other.char == char && other.attrs == attrs;

  @override
  int get hashCode => Object.hash(char, attrs);
}

/// Strips all ANSI/VT escape sequences from [s].
String _stripAnsi(String s) =>
    s.replaceAll(RegExp(r'\x1b(?:\[[0-9;?]*[A-Za-z]|[\]\(][^\x07]*\x07|\[[\d;]*m)'), '');

/// Measures the display width of [s] after stripping ANSI codes.
/// Uses [characters] for correct Unicode grapheme cluster counting.
int _ansiAwareWidth(String s) => _stripAnsi(s).characters.length;

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
  })  : _output = output,
        _logSink = logSink,
        _defaultAltScreen = defaultAltScreen,
        _defaultHideCursor = defaultHideCursor;

  final IOSink _output;
  final IOSink? _logSink;
  final bool _defaultAltScreen;
  final bool _defaultHideCursor;

  bool _altScreenEnabled = false;
  bool _cursorHidden = false;
  bool _focusReportingEnabled = false;
  bool _bracketedPasteEnabled = false;
  MouseMode _mouseMode = MouseMode.none;

  List<List<_Cell>>? _lastGrid;

  @override
  void render(View view) {
    _applyModes(view);
    if (view.windowTitle.isNotEmpty) {
      _output.write('\x1b]0;${view.windowTitle}\x07');
    }
    final nextGrid = _buildGrid(view.content);
    _diffAndEmit(nextGrid);
    _lastGrid = nextGrid;
    _logSink?.writeln('--- cell frame ---\n${view.content}');
  }

  @override
  void clearScreen() {
    _output.write('\x1b[H\x1b[2J');
    _lastGrid = null;
  }

  @override
  void insertAbove(String line) {
    if (!_altScreenEnabled) {
      _output.writeln(line);
      return;
    }
    _output.write('\x1b[s');
    _output.write('\x1b[1;1H');
    _output.write('\x1b[S');
    _output.write('\x1b[1;1H');
    _output.write(line);
    _output.write('\x1b[K');
    _output.write('\x1b[u');
    _lastGrid = null;
  }

  @override
  void release({bool reset = false}) {
    _output.write('\x1b[?25h');
    _output.write('\x1b[?1049l');
    _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
    _output.write('\x1b[?1004l');
    _output.write('\x1b[?2004l');
    _cursorHidden = false;
    _altScreenEnabled = false;
    _focusReportingEnabled = false;
    _bracketedPasteEnabled = false;
    _mouseMode = MouseMode.none;
    _lastGrid = null;
    if (reset) clearScreen();
  }

  @override
  void restore(View view) => render(view);

  @override
  void close() => release();

  @override
  void setSyncUpdates(bool enabled) {} // cell renderer handles its own sync

  // ── Grid building ──────────────────────────────────────────────────────────

  /// Parse [content] into a 2-D grid of [_Cell]s.
  /// Rows are separated by '\n'. Within each row, we walk grapheme clusters
  /// while tracking the active SGR state.
  List<List<_Cell>> _buildGrid(String content) {
    final lines = content.split('\n');
    final grid = <List<_Cell>>[];
    for (final line in lines) {
      final cells = <_Cell>[];
      var activeAttrs = '';
      var i = 0;
      // Walk the line character-by-character looking for escape sequences
      // vs printable grapheme clusters.
      //
      // Strategy: iterate over the raw string bytes; when we find \x1b, consume
      // the whole escape sequence and update activeAttrs. Otherwise the next
      // grapheme cluster is a visible cell.
      final raw = line; // raw string with ANSI codes
      while (i < raw.length) {
        if (raw[i] == '\x1b') {
          // Consume the escape sequence
          final seq = _consumeEscape(raw, i);
          if (seq.isSgr) activeAttrs = seq.raw;
          i += seq.length;
        } else {
          // Consume one grapheme cluster
          // (For ASCII this is just raw[i]; for multi-codepoint clusters we
          // need the characters iterator. We use a simple approach: iterate
          // the Characters of the remaining string and take the first one.)
          final remaining = raw.substring(i);
          final cluster = remaining.characters.first;
          cells.add(_Cell(cluster, activeAttrs));
          i += cluster.length;
        }
      }
      grid.add(cells);
    }
    return grid;
  }

  /// Emit only the cells that differ from [_lastGrid].
  void _diffAndEmit(List<List<_Cell>> next) {
    final prev = _lastGrid;
    final rows = next.length > (prev?.length ?? 0) ? next.length : (prev?.length ?? 0);
    var lastRow = -1;
    var lastCol = -1;
    var lastAttrs = '';

    for (var row = 0; row < rows; row++) {
      final nextRow = row < next.length ? next[row] : const <_Cell>[];
      final prevRow = (prev != null && row < prev.length) ? prev[row] : const <_Cell>[];
      final cols = nextRow.length > prevRow.length ? nextRow.length : prevRow.length;

      for (var col = 0; col < cols; col++) {
        final nextCell = col < nextRow.length ? nextRow[col] : const _Cell(' ', '');
        final prevCell = col < prevRow.length ? prevRow[col] : const _Cell(' ', '');

        if (nextCell == prevCell) continue;

        // Move cursor if needed
        if (lastRow != row || lastCol != col) {
          _output.write('\x1b[${row + 1};${col + 1}H');
          lastRow = row;
          lastCol = col;
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
        lastCol++;
      }
    }

    // Reset SGR if we wrote anything with attrs
    if (lastAttrs.isNotEmpty) {
      _output.write('\x1b[0m');
    }
  }

  // ── Terminal mode application (mirrors AnsiRenderer._applyModes) ───────────

  void _applyModes(View v) {
    final wantsAlt = v.altScreen || _defaultAltScreen;
    if (wantsAlt != _altScreenEnabled) {
      _output.write(wantsAlt ? '\x1b[?1049h' : '\x1b[?1049l');
      _altScreenEnabled = wantsAlt;
    }

    final wantsHiddenCursor = v.cursor == null && _defaultHideCursor;
    if (wantsHiddenCursor != _cursorHidden) {
      _output.write(wantsHiddenCursor ? '\x1b[?25l' : '\x1b[?25h');
      _cursorHidden = wantsHiddenCursor;
    }

    if (v.reportFocus != _focusReportingEnabled) {
      _output.write(v.reportFocus ? '\x1b[?1004h' : '\x1b[?1004l');
      _focusReportingEnabled = v.reportFocus;
    }

    final wantsBracketedPaste = !v.disableBracketedPasteMode;
    if (wantsBracketedPaste != _bracketedPasteEnabled) {
      _output.write(wantsBracketedPaste ? '\x1b[?2004h' : '\x1b[?2004l');
      _bracketedPasteEnabled = wantsBracketedPaste;
    }

    if (v.mouseMode != _mouseMode) {
      _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
      switch (v.mouseMode) {
        case MouseMode.none:
          break;
        case MouseMode.cellMotion:
          _output.write('\x1b[?1002h\x1b[?1006h');
          break;
        case MouseMode.allMotion:
          _output.write('\x1b[?1003h\x1b[?1006h');
          break;
      }
      _mouseMode = v.mouseMode;
    }
  }
}

// ── Escape sequence parser helper ─────────────────────────────────────────────

final class _EscSeq {
  const _EscSeq({required this.raw, required this.length, required this.isSgr});
  final String raw;
  final int length;
  final bool isSgr;
}

/// Consume one escape sequence starting at [start] in [s].
/// Returns the raw sequence, its length, and whether it's an SGR sequence.
_EscSeq _consumeEscape(String s, int start) {
  // Expect s[start] == '\x1b'
  if (start + 1 >= s.length) return _EscSeq(raw: '\x1b', length: 1, isSgr: false);

  final next = s[start + 1];
  if (next == '[') {
    // CSI sequence: \x1b[ ... final_byte (@ through ~, i.e. 0x40-0x7E)
    var i = start + 2;
    while (i < s.length && (s.codeUnitAt(i) < 0x40 || s.codeUnitAt(i) > 0x7E)) {
      i++;
    }
    if (i < s.length) i++; // include the final byte
    final raw = s.substring(start, i);
    // SGR sequences end with 'm'
    final isSgr = i > 0 && s[i - 1] == 'm';
    return _EscSeq(raw: raw, length: i - start, isSgr: isSgr);
  } else if (next == ']') {
    // OSC sequence: \x1b] ... BEL or ST
    var i = start + 2;
    while (i < s.length && s[i] != '\x07' && !(s[i] == '\x1b' && i + 1 < s.length && s[i + 1] == '\\')) {
      i++;
    }
    if (i < s.length) i++; // include BEL
    return _EscSeq(raw: s.substring(start, i), length: i - start, isSgr: false);
  } else {
    // Single-char escape (e.g. \x1b7, \x1b8)
    return _EscSeq(raw: s.substring(start, start + 2), length: 2, isSgr: false);
  }
}
