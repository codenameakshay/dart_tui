import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// Style configuration for [SpinnerModel].
final class SpinnerStyles {
  const SpinnerStyles({
    this.frame = const Style(),
    this.prefix = const Style(),
    this.suffix = const Style(),
  });

  /// Applied to the animated spinner character.
  final Style frame;

  /// Applied to the text before the spinner.
  final Style prefix;

  /// Applied to the text after the spinner.
  final Style suffix;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const SpinnerStyles defaults = SpinnerStyles(
    frame: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
  );
}

/// Indeterminate spinner driven by [TickMsg].
final class SpinnerModel extends TeaModel {
  SpinnerModel({
    this.frames = const ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
    this.index = 0,
    this.prefix = '',
    this.suffix = '',
    this.styles = SpinnerStyles.defaults,
  });

  final List<String> frames;
  final int index;
  final String prefix;
  final String suffix;
  final SpinnerStyles styles;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg && frames.isNotEmpty) {
      return (
        SpinnerModel(
          frames: frames,
          index: (index + 1) % frames.length,
          prefix: prefix,
          suffix: suffix,
          styles: styles,
        ),
        null,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final p = prefix.isEmpty ? '' : styles.prefix.render(prefix);
    final s = suffix.isEmpty ? '' : styles.suffix.render(suffix);
    if (frames.isEmpty) return newView('$p $s');
    return newView('$p${styles.frame.render(frames[index])}$s');
  }
}
