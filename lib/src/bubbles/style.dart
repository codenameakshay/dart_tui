/// Composable ANSI style object inspired by Lip Gloss primitives.
final class Style {
  const Style({
    this.foreground256,
    this.background256,
    this.foregroundRgb,
    this.backgroundRgb,
    this.isBold = false,
    this.isDim = false,
    this.padding = const EdgeInsets.all(0),
    this.margin = const EdgeInsets.all(0),
    this.border = Border.none,
  });

  final int? foreground256;
  final int? background256;
  final RgbColor? foregroundRgb;
  final RgbColor? backgroundRgb;
  final bool isBold;
  final bool isDim;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Border border;

  Style foregroundColor256(int value) => copyWith(foreground256: value);
  Style backgroundColor256(int value) => copyWith(background256: value);
  Style foregroundColorRgb(int r, int g, int b) =>
      copyWith(foregroundRgb: RgbColor(r, g, b));
  Style backgroundColorRgb(int r, int g, int b) =>
      copyWith(backgroundRgb: RgbColor(r, g, b));
  Style bold([bool value = true]) => copyWith(isBold: value);
  Style dim([bool value = true]) => copyWith(isDim: value);
  Style withPadding(EdgeInsets value) => copyWith(padding: value);
  Style withMargin(EdgeInsets value) => copyWith(margin: value);
  Style withBorder(Border value) => copyWith(border: value);

  Style copyWith({
    int? foreground256,
    int? background256,
    RgbColor? foregroundRgb,
    RgbColor? backgroundRgb,
    bool? isBold,
    bool? isDim,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Border? border,
  }) {
    return Style(
      foreground256: foreground256 ?? this.foreground256,
      background256: background256 ?? this.background256,
      foregroundRgb: foregroundRgb ?? this.foregroundRgb,
      backgroundRgb: backgroundRgb ?? this.backgroundRgb,
      isBold: isBold ?? this.isBold,
      isDim: isDim ?? this.isDim,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      border: border ?? this.border,
    );
  }

  String render(String value) {
    final lines = value.split('\n');
    final padded = _applyPadding(lines);
    final withBorder = _applyBorder(padded);
    final withMargin = _applyMargin(withBorder);
    final content = withMargin.join('\n');
    return _wrapAnsi(content);
  }

  List<String> _applyPadding(List<String> lines) {
    final maxWidth = lines.fold<int>(
      0,
      (max, line) => line.length > max ? line.length : max,
    );
    final normalized =
        lines.map((line) => line.padRight(maxWidth)).toList(growable: false);

    final out = <String>[];
    final innerWidth = maxWidth + padding.left + padding.right;
    for (var i = 0; i < padding.top; i++) {
      out.add(' ' * innerWidth);
    }
    for (final line in normalized) {
      out.add('${' ' * padding.left}$line${' ' * padding.right}');
    }
    for (var i = 0; i < padding.bottom; i++) {
      out.add(' ' * innerWidth);
    }
    return out;
  }

  List<String> _applyBorder(List<String> lines) {
    if (!border.enabled) return lines;
    final width = lines.fold<int>(
      0,
      (max, line) => line.length > max ? line.length : max,
    );
    final horizontal = border.horizontal * width;
    final out = <String>[
      '${border.topLeft}$horizontal${border.topRight}',
    ];
    for (final line in lines) {
      out.add(
        '${border.vertical}${line.padRight(width)}${border.vertical}',
      );
    }
    out.add('${border.bottomLeft}$horizontal${border.bottomRight}');
    return out;
  }

  List<String> _applyMargin(List<String> lines) {
    final width = lines.fold<int>(
      0,
      (max, line) => line.length > max ? line.length : max,
    );
    final out = <String>[];
    for (var i = 0; i < margin.top; i++) {
      out.add('');
    }
    for (final line in lines) {
      out.add(
          '${' ' * margin.left}${line.padRight(width)}${' ' * margin.right}');
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
    if (foreground256 case final fg?) open.write('\x1b[38;5;${fg}m');
    if (background256 case final bg?) open.write('\x1b[48;5;${bg}m');
    if (foregroundRgb case final fg?) {
      open.write('\x1b[38;2;${fg.r};${fg.g};${fg.b}m');
    }
    if (backgroundRgb case final bg?) {
      open.write('\x1b[48;2;${bg.r};${bg.g};${bg.b}m');
    }
    if (open.isEmpty) return value;
    return '$open$value${TuiStyle.reset}';
  }
}

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
