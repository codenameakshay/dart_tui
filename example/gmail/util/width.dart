import 'package:characters/characters.dart';

final _ansi = RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]');

/// Strips all ANSI escape sequences.
String stripAnsi(String s) => s.replaceAll(_ansi, '');

/// Terminal display width of [s] in cells. Handles wide CJK + emoji as 2 cells.
int displayWidth(String s) {
  var w = 0;
  for (final ch in stripAnsi(s).characters) {
    w += _charWidth(ch);
  }
  return w;
}

int _charWidth(String ch) {
  if (ch.isEmpty) return 0;
  final code = ch.runes.first;
  // Zero-width: combining marks, variation selectors, ZWJ, etc.
  if (code == 0x200D || code == 0xFE0F || code == 0xFE0E) return 0;
  if (code >= 0x0300 && code <= 0x036F) return 0;
  if (code >= 0x1AB0 && code <= 0x1AFF) return 0;
  if (code >= 0x1DC0 && code <= 0x1DFF) return 0;
  if (code >= 0x20D0 && code <= 0x20FF) return 0;
  // Wide ranges.
  if ((code >= 0x1100 && code <= 0x115F) ||
      (code >= 0x2E80 && code <= 0x9FFF) ||
      (code >= 0xA000 && code <= 0xA4CF) ||
      (code >= 0xAC00 && code <= 0xD7A3) ||
      (code >= 0xF900 && code <= 0xFAFF) ||
      (code >= 0xFE30 && code <= 0xFE4F) ||
      (code >= 0xFF00 && code <= 0xFF60) ||
      (code >= 0xFFE0 && code <= 0xFFE6) ||
      (code >= 0x1F300 && code <= 0x1F9FF) ||
      (code >= 0x1FA70 && code <= 0x1FAFF) ||
      (code >= 0x2600 && code <= 0x27BF)) {
    return 2;
  }
  return 1;
}

/// Pads [s] on the right with spaces so its display width == [w]. Truncates with
/// ellipsis if longer.
String fitRight(String s, int w) {
  if (w <= 0) return '';
  final dw = displayWidth(s);
  if (dw == w) return s;
  if (dw < w) return s + ' ' * (w - dw);
  return _truncate(s, w);
}

/// Pads [s] on the left (right-aligns).
String fitLeft(String s, int w) {
  if (w <= 0) return '';
  final dw = displayWidth(s);
  if (dw == w) return s;
  if (dw < w) return ' ' * (w - dw) + s;
  return _truncate(s, w);
}

String _truncate(String s, int w) {
  if (w <= 0) return '';
  if (w == 1) {
    for (final ch in stripAnsi(s).characters) {
      return ch;
    }
    return '';
  }
  // Truncate with trailing ellipsis, preserving only the visible portion.
  // We walk the (stripped) characters; ellipsis consumes 1 cell.
  final target = w - 1;
  final buf = StringBuffer();
  var used = 0;
  for (final ch in stripAnsi(s).characters) {
    final cw = _charWidth(ch);
    if (used + cw > target) break;
    buf.write(ch);
    used += cw;
  }
  return '${buf.toString()}${' ' * (target - used)}…';
}
