import 'package:characters/characters.dart';
import '../cmd.dart';
import '../grapheme_width.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Scrollable content pane.
final class ViewportModel extends TeaModel {
  ViewportModel({
    this.content = '',
    this.width = 80,
    this.height = 24,
    this.yOffset = 0,
    this.xOffset = 0,
    this.softWrap = true,
  }) : _wrappedLines = _computeWrapped(content, width, softWrap);

  /// Internal constructor for scroll-only rebuilds that reuse the already
  /// computed wrapped lines (yOffset/xOffset changes never affect wrapping).
  ViewportModel._withWrapped({
    required this.content,
    required this.width,
    required this.height,
    required this.yOffset,
    required this.xOffset,
    required this.softWrap,
    required List<String> wrappedLines,
  }) : _wrappedLines = wrappedLines;

  final String content;
  final int width;
  final int height;
  final int yOffset;
  final int xOffset;
  final bool softWrap;
  final List<String> _wrappedLines;

  static List<String> _computeWrapped(
      String content, int width, bool softWrap) {
    if (content.isEmpty) return const [''];
    final lines = content.split('\n');
    if (!softWrap) return lines;
    final result = <String>[];
    for (final line in lines) {
      // Simple ANSI strip for wrap — skip the regex entirely for the common
      // case of lines that contain no escape sequences.
      final stripped = line.contains('\x1b')
          ? line.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '')
          : line;
      if (textWidth(stripped) <= width || width <= 0) {
        result.add(line);
      } else {
        var currentLine = StringBuffer();
        var currentLineWidth = 0;
        final chars = line.characters;

        for (final char in chars) {
          final charWidth = graphemeWidth(char);
          if (currentLineWidth + charWidth > width) {
            result.add(currentLine.toString());
            currentLine = StringBuffer();
            currentLineWidth = 0;
          }
          currentLine.write(char);
          currentLineWidth += charWidth;
        }
        if (currentLine.isNotEmpty) {
          result.add(currentLine.toString());
        }
      }
    }
    return result;
  }

  int get totalLines => _wrappedLines.length;
  bool get atTop => yOffset <= 0;
  bool get atBottom => yOffset >= totalLines - height;
  double get scrollPercent =>
      totalLines <= height ? 1.0 : yOffset / (totalLines - height);

  ViewportModel _clamp(int yOff) {
    final clamped = yOff.clamp(0, (totalLines - height).clamp(0, totalLines));
    // Scroll-only change — reuse the memoized wrapped lines.
    return ViewportModel._withWrapped(
      content: content,
      width: width,
      height: height,
      yOffset: clamped,
      xOffset: xOffset,
      softWrap: softWrap,
      wrappedLines: _wrappedLines,
    );
  }

  ViewportModel _withXOffset(int xOff) => ViewportModel._withWrapped(
        content: content,
        width: width,
        height: height,
        yOffset: yOffset,
        xOffset: xOff,
        softWrap: softWrap,
        wrappedLines: _wrappedLines,
      );

  ViewportModel _rebuild({
    String? content,
    int? width,
    int? height,
    int? yOffset,
    int? xOffset,
    bool? softWrap,
  }) {
    return ViewportModel(
      content: content ?? this.content,
      width: width ?? this.width,
      height: height ?? this.height,
      yOffset: yOffset ?? this.yOffset,
      xOffset: xOffset ?? this.xOffset,
      softWrap: softWrap ?? this.softWrap,
    );
  }

  ViewportModel setContent(String newContent) =>
      _rebuild(content: newContent, yOffset: 0);

  ViewportModel scrollTo(int line) => _clamp(line);
  ViewportModel scrollBy(int delta) => _clamp(yOffset + delta);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (scrollBy(-1), null);
      case 'down':
      case 'j':
        return (scrollBy(1), null);
      case 'pgup':
      case 'ctrl+b':
        return (scrollBy(-height), null);
      case 'pgdown':
      case 'ctrl+f':
      case 'space':
        return (scrollBy(height), null);
      case 'home':
      case 'g':
        return (scrollTo(0), null);
      case 'end':
      case 'G':
        return (scrollTo(totalLines), null);
      case 'left':
        if (!softWrap) {
          return (_withXOffset((xOffset - 1).clamp(0, 9999)), null);
        }
        return (this, null);
      case 'right':
        if (!softWrap) return (_withXOffset(xOffset + 1), null);
        return (this, null);
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final end = (yOffset + height).clamp(0, _wrappedLines.length);
    final visible =
        _wrappedLines.sublist(yOffset.clamp(0, _wrappedLines.length), end);
    if (!softWrap && xOffset > 0) {
      return newView(visible.map((l) {
        if (l.length <= xOffset) return '';
        return l.substring(xOffset);
      }).join('\n'));
    }
    return newView(visible.join('\n'));
  }
}
