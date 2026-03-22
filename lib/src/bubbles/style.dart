import 'package:characters/characters.dart';

import '../msg.dart';

/// Horizontal text alignment.
enum Align { left, center, right }

/// Vertical content alignment (used when [Style.height] is set).
enum AlignVertical { top, middle, bottom }

/// Composable ANSI style object inspired by Lip Gloss primitives.
final class Style {
  const Style({
    this.foreground256,
    this.background256,
    this.foregroundRgb,
    this.backgroundRgb,
    this.adaptiveForeground,
    this.adaptiveBackground,
    this.isBold = false,
    this.isDim = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.padding = const EdgeInsets.all(0),
    this.margin = const EdgeInsets.all(0),
    this.border = Border.none,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.align = Align.left,
    this.alignVertical = AlignVertical.top,
    this.inline = false,
    this.profile,
  });

  final int? foreground256;
  final int? background256;
  final RgbColor? foregroundRgb;
  final RgbColor? backgroundRgb;
  final AdaptiveColor? adaptiveForeground;
  final AdaptiveColor? adaptiveBackground;
  final bool isBold;
  final bool isDim;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Border border;
  final int? width;
  final int? height;
  final int? maxWidth;
  final int? maxHeight;
  final Align align;
  final AlignVertical alignVertical;
  final bool inline;
  final ColorProfile? profile;

  // ── Fluent builder methods ────────────────────────────────────────────────

  Style foregroundColor256(int value) => copyWith(foreground256: value);
  Style backgroundColor256(int value) => copyWith(background256: value);
  Style foregroundColorRgb(int r, int g, int b) =>
      copyWith(foregroundRgb: RgbColor(r, g, b));
  Style backgroundColorRgb(int r, int g, int b) =>
      copyWith(backgroundRgb: RgbColor(r, g, b));
  Style bold([bool value = true]) => copyWith(isBold: value);
  Style dim([bool value = true]) => copyWith(isDim: value);
  Style italic([bool value = true]) => copyWith(isItalic: value);
  Style underline([bool value = true]) => copyWith(isUnderline: value);
  Style strikethrough([bool value = true]) => copyWith(isStrikethrough: value);
  Style withPadding(EdgeInsets value) => copyWith(padding: value);
  Style withMargin(EdgeInsets value) => copyWith(margin: value);
  Style withBorder(Border value) => copyWith(border: value);
  Style withWidth(int? value) => copyWith(width: value);
  Style withHeight(int? value) => copyWith(height: value);
  Style withMaxWidth(int? value) => copyWith(maxWidth: value);
  Style withMaxHeight(int? value) => copyWith(maxHeight: value);
  Style withAlign(Align value) => copyWith(align: value);
  Style withAlignVertical(AlignVertical value) =>
      copyWith(alignVertical: value);
  Style withInline(bool value) => copyWith(inline: value);
  Style withProfile(ColorProfile? value) => copyWith(profile: value);
  Style withAdaptiveForeground(AdaptiveColor value) =>
      copyWith(adaptiveForeground: value);
  Style withAdaptiveBackground(AdaptiveColor value) =>
      copyWith(adaptiveBackground: value);

  Style copyWith({
    int? foreground256,
    int? background256,
    RgbColor? foregroundRgb,
    RgbColor? backgroundRgb,
    AdaptiveColor? adaptiveForeground,
    AdaptiveColor? adaptiveBackground,
    bool? isBold,
    bool? isDim,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Border? border,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    Align? align,
    AlignVertical? alignVertical,
    bool? inline,
    ColorProfile? profile,
  }) {
    return Style(
      foreground256: foreground256 ?? this.foreground256,
      background256: background256 ?? this.background256,
      foregroundRgb: foregroundRgb ?? this.foregroundRgb,
      backgroundRgb: backgroundRgb ?? this.backgroundRgb,
      adaptiveForeground: adaptiveForeground ?? this.adaptiveForeground,
      adaptiveBackground: adaptiveBackground ?? this.adaptiveBackground,
      isBold: isBold ?? this.isBold,
      isDim: isDim ?? this.isDim,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      border: border ?? this.border,
      width: width ?? this.width,
      height: height ?? this.height,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      align: align ?? this.align,
      alignVertical: alignVertical ?? this.alignVertical,
      inline: inline ?? this.inline,
      profile: profile ?? this.profile,
    );
  }

  /// Render [value] with all style attributes applied.
  String render(String value) {
    if (inline) {
      // Inline mode: single line, no top/bottom padding or border
      final singleLine = value.replaceAll('\n', ' ');
      return _wrapAnsi(singleLine);
    }

    final lines = value.split('\n');
    final padded = _applyPadding(lines);
    final constrained = _applyConstraints(padded);
    final withBorder = _applyBorder(constrained);
    final withMargin = _applyMargin(withBorder);
    final content = withMargin.join('\n');
    return _wrapAnsi(content);
  }

  // ── Internal pipeline ─────────────────────────────────────────────────────

  List<String> _applyPadding(List<String> lines) {
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final innerWidth = maxW + padding.left + padding.right;

    final out = <String>[];
    for (var i = 0; i < padding.top; i++) {
      out.add(' ' * innerWidth);
    }
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final padRight = maxW - vis;
      out.add(
          '${' ' * padding.left}$line${' ' * padRight}${' ' * padding.right}');
    }
    for (var i = 0; i < padding.bottom; i++) {
      out.add(' ' * innerWidth);
    }
    return out;
  }

  List<String> _applyConstraints(List<String> lines) {
    var result = lines;

    // Width constraint: truncate lines that are too wide first
    final targetWidth = width ?? maxWidth;
    if (targetWidth != null) {
      result = result.map((line) {
        final vis = _visibleWidth(line);
        if (vis > targetWidth) {
          return _truncateVisible(line, targetWidth);
        }
        return line;
      }).toList();
    }

    // Alignment (horizontal) applied before padding to target width
    if (align != Align.left && result.isNotEmpty) {
      final effectiveWidth = width ??
          (result.fold<int>(
            0,
            (m, l) {
              final w = _visibleWidth(l);
              return w > m ? w : m;
            },
          ));
      result = result
          .map((line) => _alignLine(line, effectiveWidth, align))
          .toList();
    } else if (width != null) {
      // Left-align: pad to width
      result = result.map((line) {
        final vis = _visibleWidth(line);
        if (vis < width!) {
          return line + ' ' * (width! - vis);
        }
        return line;
      }).toList();
    }

    // Height constraint
    final targetHeight = height ?? maxHeight;
    if (targetHeight != null) {
      if (result.length > targetHeight) {
        result = result.sublist(0, targetHeight);
      } else if (height != null && result.length < height!) {
        // Vertical alignment
        final deficit = height! - result.length;
        result = _distributeVerticalPadding(result, deficit, alignVertical);
      }
    }

    return result;
  }

  static List<String> _distributeVerticalPadding(
    List<String> lines,
    int deficit,
    AlignVertical align,
  ) {
    switch (align) {
      case AlignVertical.top:
        return [...lines, ...List.filled(deficit, '')];
      case AlignVertical.bottom:
        return [...List.filled(deficit, ''), ...lines];
      case AlignVertical.middle:
        final top = deficit ~/ 2;
        final bottom = deficit - top;
        return [...List.filled(top, ''), ...lines, ...List.filled(bottom, '')];
    }
  }

  List<String> _applyBorder(List<String> lines) {
    if (!border.enabled) return lines;
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final horizontal = border.horizontal * maxW;
    final out = <String>[
      '${border.topLeft}$horizontal${border.topRight}',
    ];
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final pad = maxW - vis;
      out.add(
        '${border.vertical}$line${' ' * pad}${border.vertical}',
      );
    }
    out.add('${border.bottomLeft}$horizontal${border.bottomRight}');
    return out;
  }

  List<String> _applyMargin(List<String> lines) {
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final out = <String>[];
    for (var i = 0; i < margin.top; i++) {
      out.add('');
    }
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final pad = maxW - vis;
      out.add('${' ' * margin.left}$line${' ' * pad}${' ' * margin.right}');
    }
    for (var i = 0; i < margin.bottom; i++) {
      out.add('');
    }
    return out;
  }

  String _wrapAnsi(String value) {
    final open = StringBuffer();

    if (isBold) open.write('\x1b[1m');
    if (isDim) open.write('\x1b[2m');
    if (isItalic) open.write('\x1b[3m');
    if (isUnderline) open.write('\x1b[4m');
    if (isStrikethrough) open.write('\x1b[9m');

    // Resolve effective foreground/background considering adaptive colors and profile
    final effectiveFg = _resolveColor(
      explicit256: foreground256,
      explicitRgb: foregroundRgb,
      adaptive: adaptiveForeground,
      background: background256 != null || backgroundRgb != null,
    );
    final effectiveBg = _resolveColor(
      explicit256: background256,
      explicitRgb: backgroundRgb,
      adaptive: adaptiveBackground,
      background: false,
    );

    if (effectiveFg != null) {
      open.write(_colorCode(effectiveFg, foreground: true));
    }
    if (effectiveBg != null) {
      open.write(_colorCode(effectiveBg, foreground: false));
    }

    if (open.isEmpty) return value;
    return '$open$value${TuiStyle.reset}';
  }

  /// Resolve a color, considering adaptive colors and the active profile.
  _ResolvedColor? _resolveColor({
    int? explicit256,
    RgbColor? explicitRgb,
    AdaptiveColor? adaptive,
    required bool background,
  }) {
    final activeProfile = profile ?? ColorProfile.trueColor;
    if (activeProfile == ColorProfile.noColor) return null;

    RgbColor? rgb;
    int? idx256;

    if (adaptive != null) {
      // Use background luminance to choose light/dark variant
      final bgRgb = backgroundRgb ??
          (background256 != null ? _ansi256ToRgb(background256!) : null);
      final isDark = bgRgb == null || _isDarkBackground(bgRgb);
      rgb = isDark ? adaptive.dark : adaptive.light;
    } else if (explicitRgb != null) {
      rgb = explicitRgb;
    } else if (explicit256 != null) {
      idx256 = explicit256;
    }

    if (rgb == null && idx256 == null) return null;

    switch (activeProfile) {
      case ColorProfile.noColor:
        return null;
      case ColorProfile.ansi:
        final ansi16 = rgb != null
            ? _nearestAnsi16(rgb)
            : _nearestAnsi16(_ansi256ToRgb(idx256!));
        return _ResolvedColor.ansi16(ansi16);
      case ColorProfile.ansi256:
        if (idx256 != null) return _ResolvedColor.ansi256(idx256);
        return _ResolvedColor.ansi256(_nearestAnsi256(rgb!));
      case ColorProfile.trueColor:
        if (rgb != null) return _ResolvedColor.rgb(rgb);
        if (idx256 != null) return _ResolvedColor.ansi256(idx256);
        return null;
    }
  }

  String _colorCode(_ResolvedColor color, {required bool foreground}) {
    final base = foreground ? 38 : 48;
    return switch (color.type) {
      _ColorType.ansi16 => _ansi16Code(color.value, foreground: foreground),
      _ColorType.ansi256 => '\x1b[$base;5;${color.value}m',
      _ColorType.rgb => '\x1b[$base;2;${color.r};${color.g};${color.b}m',
    };
  }

  static String _ansi16Code(int index, {required bool foreground}) {
    // 0-7: normal colors (30-37 fg, 40-47 bg)
    // 8-15: bright colors (90-97 fg, 100-107 bg)
    if (index < 8) {
      return foreground ? '\x1b[${30 + index}m' : '\x1b[${40 + index}m';
    } else {
      return foreground
          ? '\x1b[${90 + index - 8}m'
          : '\x1b[${100 + index - 8}m';
    }
  }
}

// ── Color resolution helpers ──────────────────────────────────────────────────

enum _ColorType { ansi16, ansi256, rgb }

final class _ResolvedColor {
  const _ResolvedColor.ansi16(this.value)
      : type = _ColorType.ansi16,
        r = 0,
        g = 0,
        b = 0;
  const _ResolvedColor.ansi256(this.value)
      : type = _ColorType.ansi256,
        r = 0,
        g = 0,
        b = 0;
  _ResolvedColor.rgb(RgbColor c)
      : type = _ColorType.rgb,
        value = 0,
        r = c.r,
        g = c.g,
        b = c.b;

  final _ColorType type;
  final int value; // for ansi16/ansi256
  final int r, g, b; // for rgb
}

bool _isDarkBackground(RgbColor c) {
  final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  return lum < 128;
}

/// Map a 256-color index to approximate RGB.
RgbColor _ansi256ToRgb(int idx) {
  if (idx < 16) {
    // Standard ANSI 16 colors (approximate)
    const colors = [
      RgbColor(0, 0, 0),
      RgbColor(128, 0, 0),
      RgbColor(0, 128, 0),
      RgbColor(128, 128, 0),
      RgbColor(0, 0, 128),
      RgbColor(128, 0, 128),
      RgbColor(0, 128, 128),
      RgbColor(192, 192, 192),
      RgbColor(128, 128, 128),
      RgbColor(255, 0, 0),
      RgbColor(0, 255, 0),
      RgbColor(255, 255, 0),
      RgbColor(0, 0, 255),
      RgbColor(255, 0, 255),
      RgbColor(0, 255, 255),
      RgbColor(255, 255, 255),
    ];
    return colors[idx];
  } else if (idx < 232) {
    // 6x6x6 color cube
    final i = idx - 16;
    final r = (i ~/ 36) % 6;
    final g = (i ~/ 6) % 6;
    final b = i % 6;
    int scale(int v) => v == 0 ? 0 : 55 + v * 40;
    return RgbColor(scale(r), scale(g), scale(b));
  } else {
    // Grayscale
    final v = 8 + (idx - 232) * 10;
    return RgbColor(v, v, v);
  }
}

/// Find the nearest ANSI 16 color index for [rgb].
/// Returns 0-15 where 0-7 are standard colors and 8-15 are bright variants.
int _nearestAnsi16(RgbColor rgb) {
  // Full 16-color palette (0-7 standard, 8-15 bright)
  const palette = [
    RgbColor(0, 0, 0),
    RgbColor(128, 0, 0),
    RgbColor(0, 128, 0),
    RgbColor(128, 128, 0),
    RgbColor(0, 0, 128),
    RgbColor(128, 0, 128),
    RgbColor(0, 128, 128),
    RgbColor(192, 192, 192),
    RgbColor(128, 128, 128),
    RgbColor(255, 0, 0),
    RgbColor(0, 255, 0),
    RgbColor(255, 255, 0),
    RgbColor(0, 0, 255),
    RgbColor(255, 0, 255),
    RgbColor(0, 255, 255),
    RgbColor(255, 255, 255),
  ];
  // Map bright indices (8-15) back to standard (0-7) for code generation
  // since bright variants share hue with standard variants
  var best = 0;
  var bestDist = _colorDist(rgb, palette[0]);
  for (var i = 1; i < palette.length; i++) {
    final d = _colorDist(rgb, palette[i]);
    if (d < bestDist) {
      bestDist = d;
      // Map bright variants (8-15) to their standard counterparts (0-7)
      best = i < 8 ? i : i - 8;
    }
  }
  return best;
}

/// Find the nearest 256-color index for [rgb].
int _nearestAnsi256(RgbColor rgb) {
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < 256; i++) {
    final c = _ansi256ToRgb(i);
    final d = _colorDist(rgb, c);
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

double _colorDist(RgbColor a, RgbColor b) {
  final dr = (a.r - b.r).toDouble();
  final dg = (a.g - b.g).toDouble();
  final db = (a.b - b.b).toDouble();
  return dr * dr + dg * dg + db * db;
}

// ── Color utility functions ────────────────────────────────────────────────────

/// Lighten [c] by [amount] (0.0–1.0): blend toward white.
RgbColor lighten(RgbColor c, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return RgbColor(
    (c.r + (255 - c.r) * t).round().clamp(0, 255),
    (c.g + (255 - c.g) * t).round().clamp(0, 255),
    (c.b + (255 - c.b) * t).round().clamp(0, 255),
  );
}

/// Darken [c] by [amount] (0.0–1.0): blend toward black.
RgbColor darken(RgbColor c, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return RgbColor(
    (c.r * (1 - t)).round().clamp(0, 255),
    (c.g * (1 - t)).round().clamp(0, 255),
    (c.b * (1 - t)).round().clamp(0, 255),
  );
}

/// Linearly interpolate between [a] and [b] by [t] (0.0 = all a, 1.0 = all b).
RgbColor blend(RgbColor a, RgbColor b, double t) {
  final s = t.clamp(0.0, 1.0);
  return RgbColor(
    (a.r + (b.r - a.r) * s).round().clamp(0, 255),
    (a.g + (b.g - a.g) * s).round().clamp(0, 255),
    (a.b + (b.b - a.b) * s).round().clamp(0, 255),
  );
}

// ── Width helpers ─────────────────────────────────────────────────────────────

final _ansiEscapeRe = RegExp(r'\x1b(?:\[[0-9;?]*[A-Za-z]|[\]O][^\x07]*\x07?)');

/// Strip ANSI escape sequences from [s].
String _stripAnsiStyle(String s) => s.replaceAll(_ansiEscapeRe, '');

/// Visible display width of [s] (number of printable characters after stripping ANSI).
int _visibleWidth(String s) => _stripAnsiStyle(s).length;

/// Truncate [s] to at most [maxWidth] visible characters, preserving ANSI codes.
String _truncateVisible(String s, int maxWidth) {
  if (_visibleWidth(s) <= maxWidth) return s;
  var count = 0;
  final b = StringBuffer();
  var i = 0;
  while (i < s.length && count < maxWidth) {
    if (s[i] == '\x1b') {
      // consume escape sequence
      final match = _ansiEscapeRe.matchAsPrefix(s, i);
      if (match != null) {
        b.write(match.group(0));
        i += match.group(0)!.length;
        continue;
      }
    }
    b.write(s[i]);
    count++;
    i++;
  }
  return b.toString();
}

/// Align [line] within [maxWidth] according to [align].
String _alignLine(String line, int maxWidth, Align align) {
  final vis = _visibleWidth(line);
  if (vis >= maxWidth) return line;
  final pad = maxWidth - vis;
  return switch (align) {
    Align.left => '$line${' ' * pad}',
    Align.right => '${' ' * pad}$line',
    Align.center => '${' ' * (pad ~/ 2)}$line${' ' * (pad - pad ~/ 2)}',
  };
}

// ── Join / Place functions ────────────────────────────────────────────────────

/// Join styled blocks side-by-side (horizontal composition).
///
/// [alignment] controls vertical alignment: 0.0 = top, 0.5 = center, 1.0 = bottom.
/// Shorter blocks are padded with blank lines to match the tallest block.
String joinHorizontal(double alignment, List<String> blocks) {
  if (blocks.isEmpty) return '';
  if (blocks.length == 1) return blocks.first;

  final split = blocks.map((b) => b.split('\n')).toList();
  final maxLines = split.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  final widths = split
      .map((l) => l.fold<int>(0, (m, s) {
            final w = _visibleWidth(s);
            return w > m ? w : m;
          }))
      .toList();

  // Pad each block to maxLines
  final padded = List.generate(split.length, (bi) {
    final lines = split[bi];
    final deficit = maxLines - lines.length;
    if (deficit == 0) return lines;
    final top = (deficit * alignment).round();
    final bottom = deficit - top;
    final w = widths[bi];
    return [
      ...List.generate(top, (_) => ' ' * w),
      ...lines,
      ...List.generate(bottom, (_) => ' ' * w),
    ];
  });

  // Zip line-by-line: pad each block's line to its column width
  final result = List.generate(maxLines, (row) {
    return List.generate(split.length, (bi) {
      final line = padded[bi][row];
      final vis = _visibleWidth(line);
      final pad = widths[bi] - vis;
      return pad > 0 ? '$line${' ' * pad}' : line;
    }).join('');
  });

  return result.join('\n');
}

/// Join blocks vertically (stacked), padding narrower blocks to widest width.
///
/// [alignment] controls horizontal alignment: 0.0 = left, 0.5 = center, 1.0 = right.
String joinVertical(double alignment, List<String> blocks) {
  if (blocks.isEmpty) return '';
  if (blocks.length == 1) return blocks.first;

  final allLines = blocks.expand((b) => b.split('\n')).toList();

  // For left alignment, no padding is added (lines stay as-is)
  if (alignment <= 0.0) {
    return allLines.join('\n');
  }

  final maxW = allLines.fold<int>(0, (m, l) {
    final w = _visibleWidth(l);
    return w > m ? w : m;
  });

  final align = alignment >= 1.0 ? Align.right : Align.center;

  return allLines.map((l) => _alignLine(l, maxW, align)).join('\n');
}

/// Place [content] within a box of [width] x [height].
///
/// [hAlign] and [vAlign] control placement: 0.0 = top/left, 1.0 = bottom/right.
String place(
  int width,
  int height,
  double hAlign,
  double vAlign,
  String content,
) {
  return placeVertical(height, vAlign, placeHorizontal(width, hAlign, content));
}

/// Center [content] horizontally within [width] columns.
String placeHorizontal(int width, double align, String content) {
  final lines = content.split('\n');
  final aligned = lines.map((line) {
    final vis = _visibleWidth(line);
    if (vis >= width) return line;
    final pad = width - vis;
    final left = (pad * align).round();
    final right = pad - left;
    return '${' ' * left}$line${' ' * right}';
  });
  return aligned.join('\n');
}

/// Place [content] vertically within [height] rows.
String placeVertical(int height, double align, String content) {
  final lines = content.split('\n');
  if (lines.length >= height) return content;
  final deficit = height - lines.length;
  final top = (deficit * align).round();
  final bottom = deficit - top;
  return [
    ...List.filled(top, ''),
    ...lines,
    ...List.filled(bottom, ''),
  ].join('\n');
}

// ── Supporting types ──────────────────────────────────────────────────────────

final class EdgeInsets {
  const EdgeInsets({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  const EdgeInsets.all(int value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  final int top;
  final int right;
  final int bottom;
  final int left;
}

final class Border {
  const Border({
    required this.enabled,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
  });

  static const none = Border(
    enabled: false,
    topLeft: '',
    topRight: '',
    bottomLeft: '',
    bottomRight: '',
    horizontal: '',
    vertical: '',
  );

  static const rounded = Border(
    enabled: true,
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    horizontal: '─',
    vertical: '│',
  );

  static const box = Border(
    enabled: true,
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    horizontal: '─',
    vertical: '│',
  );

  static const thick = Border(
    enabled: true,
    topLeft: '┏',
    topRight: '┓',
    bottomLeft: '┗',
    bottomRight: '┛',
    horizontal: '━',
    vertical: '┃',
  );

  // ignore: constant_identifier_names
  static const double = Border(
    enabled: true,
    topLeft: '╔',
    topRight: '╗',
    bottomLeft: '╚',
    bottomRight: '╝',
    horizontal: '═',
    vertical: '║',
  );

  final bool enabled;
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String horizontal;
  final String vertical;
}

final class RgbColor {
  const RgbColor(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

/// Adaptive color that selects between [light] and [dark] variants based on
/// the terminal background luminance.
final class AdaptiveColor {
  const AdaptiveColor({required this.light, required this.dark});
  final RgbColor light;
  final RgbColor dark;
}

/// Minimal compatibility ANSI helpers.
abstract final class TuiStyle {
  static const reset = '\x1b[0m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';

  static String fg256(int n) => '\x1b[38;5;${n}m';
  static String bg256(int n) => '\x1b[48;5;${n}m';
  static String fgRgb(int r, int g, int b) => '\x1b[38;2;$r;$g;${b}m';
  static String bgRgb(int r, int g, int b) => '\x1b[48;2;$r;$g;${b}m';

  static String wrap(String s, {String open = '', String close = reset}) =>
      '$open$s$close';
}

// ── Gradient text functions ────────────────────────────────────────────────────

/// Render [text] with a per-character horizontal foreground color gradient
/// smoothly blended across [colors].
///
/// [colors] must have at least 2 entries. The gradient is computed in true-color
/// RGB space; each grapheme cluster receives its own `\x1b[38;2;r;g;bm` code.
/// Use [gradientBackground] for background gradients.
///
/// Example:
/// ```dart
/// gradientText('Hello, world!', [RgbColor(255,0,128), RgbColor(0,200,255)])
/// ```
String gradientText(String text, List<RgbColor> colors) {
  assert(colors.length >= 2, 'gradientText requires at least 2 colors');
  final chars = text.characters.toList();
  if (chars.isEmpty) return '';
  final b = StringBuffer();
  final n = colors.length - 1; // number of segments
  for (var i = 0; i < chars.length; i++) {
    final t = chars.length == 1 ? 0.0 : i / (chars.length - 1);
    final seg = (t * n).floor().clamp(0, n - 1);
    final localT = (t * n) - seg;
    final c = blend(colors[seg], colors[seg + 1], localT);
    b.write('\x1b[38;2;${c.r};${c.g};${c.b}m${chars[i]}');
  }
  b.write('\x1b[0m');
  return b.toString();
}

/// Render [text] with a per-character horizontal background color gradient.
///
/// Like [gradientText] but applies colors to the background (`\x1b[48;2;...`).
/// An optional [foreground] [Style] is applied to the whole string.
String gradientBackground(
  String text,
  List<RgbColor> colors, {
  Style? foreground,
}) {
  assert(colors.length >= 2, 'gradientBackground requires at least 2 colors');
  final chars = text.characters.toList();
  if (chars.isEmpty) return '';
  final fgCode = foreground != null ? _extractFgCode(foreground) : '';
  final b = StringBuffer();
  final n = colors.length - 1;
  for (var i = 0; i < chars.length; i++) {
    final t = chars.length == 1 ? 0.0 : i / (chars.length - 1);
    final seg = (t * n).floor().clamp(0, n - 1);
    final localT = (t * n) - seg;
    final c = blend(colors[seg], colors[seg + 1], localT);
    b.write('\x1b[48;2;${c.r};${c.g};${c.b}m$fgCode${chars[i]}');
  }
  b.write('\x1b[0m');
  return b.toString();
}

/// Extract the foreground ANSI code string from a [Style] (no layout applied).
String _extractFgCode(Style s) {
  if (s.foregroundRgb != null) {
    final c = s.foregroundRgb!;
    return '\x1b[38;2;${c.r};${c.g};${c.b}m';
  }
  if (s.foreground256 != null) return '\x1b[38;5;${s.foreground256}m';
  if (s.isBold) return '\x1b[1m';
  return '';
}

// ── Background detection helper ────────────────────────────────────────────────

/// Returns `true` if the packed RGB integer [rgb] (as returned by
/// [BackgroundColorMsg.rgb]) represents a dark background.
///
/// Uses the ITU-R BT.601 luminance formula; values below 128 are considered dark.
bool isDarkRgb(int rgb) {
  final r = (rgb >> 16) & 0xff;
  final g = (rgb >> 8) & 0xff;
  final b = rgb & 0xff;
  final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return lum < 128;
}
