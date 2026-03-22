import 'style.dart';

/// A single painted cell: one grapheme cluster with its accumulated ANSI
/// prefix (SGR open codes). The reset is emitted once by [Canvas.render].
final class _Cell {
  const _Cell({this.char = ' ', this.ansiOpen = ''});
  final String char;
  final String ansiOpen;

  bool get isStyled => ansiOpen.isNotEmpty;
}

/// An instruction to paint [content] at ([x], [y]) with a given [zIndex].
final class _Layer {
  const _Layer({
    required this.x,
    required this.y,
    required this.zIndex,
    required this.content,
  });
  final int x;
  final int y;
  final int zIndex;
  final String content;
}

/// A 2-D painting surface for compositing styled text blocks at arbitrary
/// positions with z-index layering.
///
/// Usage:
/// ```dart
/// final canvas = Canvas(60, 20);
/// canvas.paint(0, 0,
///   Style().backgroundColorRgb(40, 40, 60).withWidth(60).withHeight(20).render(''),
///   zIndex: 0,
/// );
/// canvas.paint(5, 3,
///   Style().foregroundColorRgb(203, 166, 247).bold().render('Hello!'),
///   zIndex: 1,
/// );
/// final output = canvas.render();
/// ```
///
/// Higher [zIndex] layers overwrite lower ones at overlapping cells.
/// All layers are collapsed into a flat string when [render] is called.
final class Canvas {
  Canvas(this.width, this.height)
      : assert(width > 0 && height > 0,
            'Canvas width and height must be positive');

  final int width;
  final int height;

  final List<_Layer> _layers = [];

  /// Paint [content] at column [x], row [y] with optional [zIndex].
  ///
  /// [content] may contain ANSI escape codes (e.g. from [Style.render]).
  /// Multi-line content (newlines) is supported: each line is painted on
  /// successive rows starting from [y].
  ///
  /// If [style] is provided it is applied to [content] before painting.
  void paint(int x, int y, String content, {int zIndex = 0, Style? style}) {
    final rendered = style != null ? style.render(content) : content;
    _layers.add(_Layer(x: x, y: y, zIndex: zIndex, content: rendered));
  }

  /// Clear all layers, resetting the canvas to blank.
  void clear() => _layers.clear();

  /// Collapse all layers into a final string ready for display.
  ///
  /// Layers are drawn in ascending [zIndex] order (lower z first, higher z on top).
  String render() {
    // Initialise grid
    final grid = List.generate(
      height,
      (_) => List<_Cell>.filled(width, const _Cell()),
    );

    // Draw layers in ascending z order
    final sorted = List<_Layer>.from(_layers)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final layer in sorted) {
      _paintLayer(grid, layer);
    }

    // Serialise grid rows → string
    final sb = StringBuffer();
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final cell = grid[row][col];
        if (cell.isStyled) {
          sb.write('${cell.ansiOpen}${cell.char}\x1b[0m');
        } else {
          sb.write(cell.char);
        }
      }
      if (row < height - 1) sb.write('\n');
    }
    return sb.toString();
  }

  void _paintLayer(List<List<_Cell>> grid, _Layer layer) {
    final lines = layer.content.split('\n');
    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final row = layer.y + lineIdx;
      if (row < 0 || row >= height) continue;
      _paintStyledLine(grid[row], layer.x, lines[lineIdx]);
    }
  }

  /// Parse [line] (which may contain ANSI codes) into grapheme clusters,
  /// tracking the current SGR state, and write cells into [gridRow] starting
  /// at column [startX].
  void _paintStyledLine(List<_Cell> gridRow, int startX, String line) {
    var col = startX;
    var i = 0;
    final ansiRe = RegExp(r'\x1b(?:\[[0-9;?]*[A-Za-z]|[\]O][^\x07]*\x07?)');
    var currentAnsi = StringBuffer();

    while (i < line.length) {
      // Check for an escape sequence at position i
      final match = ansiRe.matchAsPrefix(line, i);
      if (match != null) {
        final seq = match.group(0)!;
        i += seq.length;
        // Reset clears accumulated state
        if (seq == '\x1b[0m' || seq == '\x1b[m') {
          currentAnsi.clear();
        } else {
          currentAnsi.write(seq);
        }
        continue;
      }

      // Printable grapheme cluster: consume one rune
      final rune = line.runes.elementAt(0 + _runeOffset(line, i));
      final char = String.fromCharCode(rune);
      i += char.length;

      if (col >= 0 && col < gridRow.length) {
        gridRow[col] = _Cell(
          char: char,
          ansiOpen: currentAnsi.toString(),
        );
      }
      col++;
    }
  }

  /// Return the rune index for byte offset [byteOffset] in [s].
  static int _runeOffset(String s, int byteOffset) {
    var idx = 0;
    var pos = 0;
    for (final r in s.runes) {
      if (pos == byteOffset) return idx;
      pos += String.fromCharCode(r).length;
      idx++;
    }
    return idx;
  }
}

/// A [Canvas]-backed [TeaModel]-compatible helper that wraps a [Canvas] in a
/// static (non-interactive) view. Useful for compositing views inside larger
/// layouts.
///
/// For interactive canvases, embed [Canvas] in your own [TeaModel.view()].
final class CanvasView {
  CanvasView(this.canvas);
  final Canvas canvas;

  /// Returns the rendered canvas content as a plain string.
  String render() => canvas.render();
}
