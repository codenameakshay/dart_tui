import 'dart:io';

import 'view.dart';

abstract interface class TeaRenderer {
  void render(View view);
  void clearScreen();
  void insertAbove(String line);
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

  @override
  void render(View view) {
    _applyModes(view);
    if (view.windowTitle.isNotEmpty) {
      _output.write('\x1b]0;${view.windowTitle}\x07');
    }
    _output.write('\x1b[H\x1b[2J');
    _output.write(view.content);
    _logSink?.writeln('--- frame ---\n${view.content}');
  }

  @override
  void clearScreen() {
    _output.write('\x1b[H\x1b[2J');
  }

  @override
  void insertAbove(String line) {
    if (!_altScreenEnabled) {
      _output.writeln(line);
    }
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
