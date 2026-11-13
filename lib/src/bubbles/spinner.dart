import '../cmd.dart';
import '../cmd.dart' as cmd show tick;
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

/// A spinner's frames and the time each frame stays on screen.
///
/// The presets match Bubble Tea's `bubbles/spinner` (spinner.go): the same
/// frames and the same speeds (Bubble Tea's `FPS` field is an interval).
/// Frames inside a preset are padded to one display width, so text after the
/// spinner does not move.
final class Spinner {
  const Spinner(this.frames, this.interval);

  final List<String> frames;
  final Duration interval;

  static const line = Spinner(
    ['|', '/', '-', r'\'],
    Duration(milliseconds: 100),
  );
  static const dot = Spinner(
    ['⣾ ', '⣽ ', '⣻ ', '⢿ ', '⡿ ', '⣟ ', '⣯ ', '⣷ '],
    Duration(milliseconds: 100),
  );
  static const miniDot = Spinner(
    ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
    Duration(microseconds: 83333),
  );
  static const jump = Spinner(
    ['⢄', '⢂', '⢁', '⡁', '⡈', '⡐', '⡠'],
    Duration(milliseconds: 100),
  );
  static const pulse = Spinner(
    ['█', '▓', '▒', '░'],
    Duration(milliseconds: 125),
  );
  static const points = Spinner(
    ['∙∙∙', '●∙∙', '∙●∙', '∙∙●'],
    Duration(microseconds: 142857),
  );
  static const globe = Spinner(
    ['🌍', '🌎', '🌏'],
    Duration(milliseconds: 250),
  );
  static const moon = Spinner(
    ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'],
    Duration(milliseconds: 125),
  );
  static const monkey = Spinner(
    ['🙈', '🙉', '🙊'],
    Duration(microseconds: 333333),
  );
  static const meter = Spinner(
    ['▱▱▱', '▰▱▱', '▰▰▱', '▰▰▰', '▰▰▱', '▰▱▱', '▱▱▱'],
    Duration(microseconds: 142857),
  );
  static const hamburger = Spinner(
    ['☱', '☲', '☴', '☲'],
    Duration(microseconds: 333333),
  );

  /// Bubble Tea's first frame is empty; here every frame is three cells wide.
  static const ellipsis = Spinner(
    ['   ', '.  ', '.. ', '...'],
    Duration(microseconds: 333333),
  );
}

/// Indeterminate spinner driven by [TickMsg].
///
/// Without an [id] it advances on every [TickMsg] that has no id, such as the
/// ticks from `withTickInterval`. With an [id] it runs its own chain: return
/// [tick] once (from `init` or `update`), forward every [TickMsg] to it, and
/// return the [Cmd] its `update` gives back. It then advances only on ticks
/// with its [id], at its [spinner]'s interval. As in Bubble Tea, each tick
/// carries a tag, and a tick from an older chain is dropped, so calling [tick]
/// again does not speed it up.
final class SpinnerModel extends Model {
  SpinnerModel({
    List<String>? frames,
    Spinner? spinner,
    this.index = 0,
    this.prefix = '',
    this.suffix = '',
    this.styles = SpinnerStyles.defaults,
    this.id,
  })  : spinner = frames == null
            ? spinner ?? Spinner.miniDot
            : Spinner(frames, (spinner ?? Spinner.miniDot).interval),
        _tag = 0;

  SpinnerModel._(
    this.spinner,
    this.index,
    this.prefix,
    this.suffix,
    this.styles,
    this.id,
    this._tag,
  );

  /// Frames and interval. `frames` passed to the constructor replace the
  /// preset's frames and keep its interval.
  final Spinner spinner;
  final int index;
  final String prefix;
  final String suffix;
  final SpinnerStyles styles;

  /// Routes ticks to this spinner. `null` follows the id-less global tick.
  final Object? id;

  final int _tag;

  List<String> get frames => spinner.frames;

  /// Starts this spinner's tick chain. It advances one frame at once; with an
  /// [id], each `update` then returns the next tick at the spinner's interval.
  Cmd tick() => () => TickMsg(DateTime.now(), id: id, tag: _tag);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! TickMsg || frames.isEmpty) return (this, null);
    if (msg.id != id) return (this, null);
    if (msg.tag != 0 && msg.tag != _tag) return (this, null);
    final tag = _tag + 1;
    final next = SpinnerModel._(
      spinner,
      (index + 1) % frames.length,
      prefix,
      suffix,
      styles,
      id,
      tag,
    );
    if (id == null) return (next, null);
    return (
      next,
      cmd.tick(spinner.interval, (t) => TickMsg(t, id: id, tag: tag))
    );
  }

  @override
  View view() {
    final p = prefix.isEmpty ? '' : styles.prefix.render(prefix);
    final s = suffix.isEmpty ? '' : styles.suffix.render(suffix);
    if (frames.isEmpty) return newView('$p $s');
    return newView('$p${styles.frame.render(frames[index])}$s');
  }
}
