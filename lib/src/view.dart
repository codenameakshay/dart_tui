import 'cmd.dart';
import 'msg.dart';

/// Declarative terminal view.
final class View {
  View({
    this.content = '',
    this.onMouse,
    this.cursor,
    this.backgroundColor,
    this.foregroundColor,
    this.windowTitle = '',
    this.progressBar,
    this.altScreen = false,
    this.reportFocus = false,
    this.disableBracketedPasteMode = false,
    this.mouseMode = MouseMode.none,
    this.keyboardEnhancements = const KeyboardEnhancements(),
  });

  String content;
  Cmd? Function(MouseMsg msg)? onMouse;
  Cursor? cursor;
  int? backgroundColor;
  int? foregroundColor;
  String windowTitle;
  ProgressBar? progressBar;
  bool altScreen;
  bool reportFocus;
  bool disableBracketedPasteMode;
  MouseMode mouseMode;
  KeyboardEnhancements keyboardEnhancements;

  void setContent(String s) => content = s;
}

View newView(String s) => View(content: s);

enum MouseMode {
  none,
  cellMotion,
  allMotion,
}

enum ProgressBarState {
  none,
  normal,
  error,
  indeterminate,
  warning,
}

final class ProgressBar {
  const ProgressBar({
    required this.state,
    required this.value,
  });

  final ProgressBarState state;
  final int value;
}

enum CursorShape {
  block,
  underline,
  bar,
}

final class Cursor {
  const Cursor({
    required this.x,
    required this.y,
    this.color,
    this.shape = CursorShape.block,
    this.blink = true,
  });

  final int x;
  final int y;
  final int? color;
  final CursorShape shape;
  final bool blink;
}

final class KeyboardEnhancements {
  const KeyboardEnhancements({
    this.reportEventTypes = false,
  });

  final bool reportEventTypes;
}
