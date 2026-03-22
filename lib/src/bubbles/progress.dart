import '../cmd.dart';
import '../model.dart';
import '../msg.dart' show Msg;
import '../view.dart';
import 'style.dart';

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
  }) : assert(fraction >= 0 && fraction <= 1, 'fraction must be 0..1');

  final double fraction;
  final int width;
  final String label;
  final ProgressStyles styles;

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() {
    final filled = (fraction * width).round().clamp(0, width);
    final bar = styles.filled.render('█' * filled) +
        styles.empty.render('░' * (width - filled));
    final pct = (fraction * 100).round();
    final labelPart =
        label.isEmpty ? '' : '${styles.label.render(label)} ';
    return newView('$labelPart$bar ${styles.percent.render('$pct%')}');
  }
}
