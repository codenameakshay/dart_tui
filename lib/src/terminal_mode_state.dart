import 'dart:io';

import 'view.dart';

/// Owns terminal modes shared by every renderer implementation.
final class TerminalModeState {
  TerminalModeState({
    required bool defaultAltScreen,
    required bool defaultHideCursor,
    MouseMode defaultMouseMode = MouseMode.none,
    bool defaultReportFocus = false,
  })  : _defaultAltScreen = defaultAltScreen,
        _defaultHideCursor = defaultHideCursor,
        _defaultMouseMode = defaultMouseMode,
        _defaultReportFocus = defaultReportFocus;

  final bool _defaultAltScreen;
  final bool _defaultHideCursor;
  final MouseMode _defaultMouseMode;
  final bool _defaultReportFocus;

  bool get altScreenEnabled => _altScreenEnabled;

  bool _altScreenEnabled = false;
  bool _cursorHidden = false;
  bool _focusReportingEnabled = false;
  bool _bracketedPasteEnabled = false;
  MouseMode _mouseMode = MouseMode.none;

  bool effectiveAltScreen(View view) => view.altScreen || _defaultAltScreen;

  /// Applies [view] modes and returns whether the screen buffer changed.
  bool apply(IOSink output, View view) {
    final screenChanged = _setAltScreen(
      output,
      effectiveAltScreen(view),
    );

    final wantsHiddenCursor = view.cursor == null && _defaultHideCursor;
    _setCursorHidden(output, wantsHiddenCursor);

    final wantsFocus = view.reportFocus || _defaultReportFocus;
    if (wantsFocus != _focusReportingEnabled) {
      output.write(wantsFocus ? '\x1b[?1004h' : '\x1b[?1004l');
      _focusReportingEnabled = wantsFocus;
    }

    final wantsBracketedPaste = !view.disableBracketedPasteMode;
    if (wantsBracketedPaste != _bracketedPasteEnabled) {
      output.write(wantsBracketedPaste ? '\x1b[?2004h' : '\x1b[?2004l');
      _bracketedPasteEnabled = wantsBracketedPaste;
    }

    final effectiveMouseMode = view.mouseMode.index >= _defaultMouseMode.index
        ? view.mouseMode
        : _defaultMouseMode;
    if (effectiveMouseMode != _mouseMode) {
      output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
      switch (effectiveMouseMode) {
        case MouseMode.none:
          break;
        case MouseMode.cellMotion:
          output.write('\x1b[?1002h\x1b[?1006h');
        case MouseMode.allMotion:
          output.write('\x1b[?1003h\x1b[?1006h');
      }
      _mouseMode = effectiveMouseMode;
    }

    return screenChanged;
  }

  bool setAltScreen(IOSink output, bool enabled) =>
      _setAltScreen(output, enabled);

  bool setCursorVisibility(IOSink output, bool visible) =>
      _setCursorHidden(output, !visible);

  void reset(IOSink output) {
    output.write('\x1b[?25h');
    // Only exit the alternate screen when it is actually active (#18). On the
    // primary buffer the sequence triggers a spurious buffer/cursor restore.
    if (_altScreenEnabled) {
      output.write('\x1b[?1049l');
      _altScreenEnabled = false;
    }
    output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
    output.write('\x1b[?1004l');
    output.write('\x1b[?2004l');
    _cursorHidden = false;
    _focusReportingEnabled = false;
    _bracketedPasteEnabled = false;
    _mouseMode = MouseMode.none;
  }

  bool _setAltScreen(IOSink output, bool enabled) {
    if (enabled == _altScreenEnabled) return false;
    output.write(enabled ? '\x1b[?1049h' : '\x1b[?1049l');
    _altScreenEnabled = enabled;
    return true;
  }

  bool _setCursorHidden(IOSink output, bool hidden) {
    if (hidden == _cursorHidden) return false;
    output.write(hidden ? '\x1b[?25l' : '\x1b[?25h');
    _cursorHidden = hidden;
    return true;
  }
}
