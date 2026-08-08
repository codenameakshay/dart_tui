import '../cmd.dart';
import '../model.dart';
import '../msg.dart' show Msg;
import '../view.dart';
import 'style.dart';

typedef ProgressColorBuilder = RgbColor Function(
  double total,
  double current,
);

/// Style configuration for [ProgressModel].
final class ProgressStyles {
  const ProgressStyles({
    this.filled = const Style(),
    this.empty = const Style(),
    this.label = const Style(),
    this.percent = const Style(),
  });

  /// Applied to the filled portion of the bar (`█` chars).
  final Style filled;

  /// Applied to the empty portion of the bar (`░` chars).
  final Style empty;

  /// Applied to the optional label prefix.
  final Style label;

  /// Applied to the percentage readout.
  final Style percent;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const ProgressStyles defaults = ProgressStyles(
    filled: Style(foregroundRgb: RgbColor(203, 166, 247)), // Mauve
    empty: Style(foregroundRgb: RgbColor(88, 91, 112)), // Surface2
    label: Style(foregroundRgb: RgbColor(166, 173, 200)), // Subtext0
    percent: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
      isBold: true,
    ),
  );
}

/// Simple determinate progress bar (0.0–1.0).
final class ProgressModel extends TeaModel {
  ProgressModel({
    required this.fraction,
    this.width = 40,
    this.label = '',
    this.styles = ProgressStyles.defaults,
    List<RgbColor> colors = const <RgbColor>[],
    this.scaleGradient = false,
    this.colorBuilder,
  })  : colors = List<RgbColor>.unmodifiable(colors),
        assert(fraction >= 0 && fraction <= 1, 'fraction must be 0..1'),
        assert(width >= 0, 'width must not be negative');

  final double fraction;
  final int width;
  final String label;
  final ProgressStyles styles;
  final List<RgbColor> colors;
  final bool scaleGradient;
  final ProgressColorBuilder? colorBuilder;

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() {
    final filled = (fraction * width).round().clamp(0, width);
    final bar =
        _renderFilled(filled) + styles.empty.render('░' * (width - filled));
    final pct = (fraction * 100).round();
    final labelPart = label.isEmpty ? '' : '${styles.label.render(label)} ';
    return newView('$labelPart$bar ${styles.percent.render('$pct%')}');
  }

  String _renderFilled(int filled) {
    if (filled == 0) return '';
    final builder = colorBuilder;
    if (builder != null) {
      final output = StringBuffer();
      for (var cell = 0; cell < filled; cell++) {
        final current = width == 0 ? 0.0 : cell / width;
        output.write(_renderCell(builder(fraction, current)));
      }
      return output.toString();
    }

    if (colors.length >= 2) {
      final gradientWidth = scaleGradient ? filled : width;
      final output = StringBuffer();
      for (var cell = 0; cell < filled; cell++) {
        output.write(_renderCell(_sampleGradient(colors, cell, gradientWidth)));
      }
      return output.toString();
    }

    if (colors.length == 1) {
      return _filledStyle(colors.single).render('█' * filled);
    }
    return styles.filled.render('█' * filled);
  }

  String _renderCell(RgbColor color) => _filledStyle(color).render('█');

  Style _filledStyle(RgbColor color) {
    final base = styles.filled;
    return Style(
      foregroundRgb: color,
      background256: base.background256,
      backgroundRgb: base.backgroundRgb,
      backgroundComplete: base.backgroundComplete,
      adaptiveBackground: base.adaptiveBackground,
      isBold: base.isBold,
      isDim: base.isDim,
      isItalic: base.isItalic,
      isUnderline: base.isUnderline,
      isStrikethrough: base.isStrikethrough,
      isReverse: base.isReverse,
      isBlink: base.isBlink,
      isOverline: base.isOverline,
      underlineSpaces: base.underlineSpaces,
      strikethroughSpaces: base.strikethroughSpaces,
      padding: base.padding,
      margin: base.margin,
      border: base.border,
      borderForeground: base.borderForeground,
      borderBackground: base.borderBackground,
      marginBackground: base.marginBackground,
      borderTitle: base.borderTitle,
      borderTitleAlignment: base.borderTitleAlignment,
      width: base.width,
      height: base.height,
      maxWidth: base.maxWidth,
      maxHeight: base.maxHeight,
      align: base.align,
      alignVertical: base.alignVertical,
      inline: base.inline,
      wordWrap: base.wordWrap,
      tabWidth: base.tabWidth,
      profile: base.profile,
      transform: base.transform,
    );
  }

  static RgbColor _sampleGradient(
    List<RgbColor> palette,
    int index,
    int sampleCount,
  ) {
    if (sampleCount <= 1) return palette.first;
    final position = index.clamp(0, sampleCount - 1) / (sampleCount - 1);
    final scaled = position * (palette.length - 1);
    final segment = scaled.floor().clamp(0, palette.length - 2);
    return blend(palette[segment], palette[segment + 1], scaled - segment);
  }
}
