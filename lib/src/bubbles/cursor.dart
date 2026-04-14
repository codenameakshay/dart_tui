import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// The visual shape rendered for the cursor character.
enum CursorMode {
  /// A solid block: `█` (default).
  block,

  /// An underscore: `_`.
  underline,

  /// A vertical bar: `|`.
  bar,
}

/// Style configuration for [CursorModel].
final class CursorStyles {
  const CursorStyles({
    this.focused = const Style(),
    this.blurred = const Style(),
  });

  /// Applied to the cursor character when the parent field is focused.
  final Style focused;

  /// Applied to the cursor character when the parent field is blurred.
  final Style blurred;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const CursorStyles defaults = CursorStyles(
    focused: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    blurred: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
      isDim: true,
    ),
  );
}

/// A blinking cursor bubble.
///
/// Designed to be embedded inside text-input components. The cursor renders
/// as a single styled character (block `█`, underline `_`, or bar `|`) that
/// blinks on each [TickMsg].
///
/// Typical usage inside a parent model:
/// ```dart
/// // In parent update():
/// if (msg is TickMsg) {
///   final (next, cmd) = cursor.update(msg);
///   cursor = next as CursorModel;
///   return (this.copyWith(cursor: cursor), cmd);
/// }
///
/// // In parent view():
/// '$text${cursor.view().content}';
/// ```
final class CursorModel extends TeaModel {
  CursorModel({
    this.mode = CursorMode.block,
    this.blink = true,
    this.visible = true,
    this.focused = true,
    this.styles = CursorStyles.defaults,
  });

  /// The visual shape of the cursor character.
  final CursorMode mode;

  /// Whether the cursor should blink (toggle on [TickMsg]).
  final bool blink;

  /// Current visibility state (toggled by blink).
  final bool visible;

  /// Whether the parent field is focused. When `false`, renders with
  /// [CursorStyles.blurred] and does not blink.
  final bool focused;

  final CursorStyles styles;

  /// The cursor character for the current [mode].
  String get _char => switch (mode) {
        CursorMode.block => '█',
        CursorMode.underline => '_',
        CursorMode.bar => '|',
      };

  /// Return a copy focused/blurred.
  CursorModel focus() => _copy(focused: true, visible: true);
  CursorModel blur() => _copy(focused: false, visible: true);

  /// Return a copy with a different mode.
  CursorModel withMode(CursorMode m) => _copy(mode: m);

  /// Return a copy with blink toggled.
  CursorModel withBlink(bool b) => _copy(blink: b);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (!focused || !blink) return (this, null);
    if (msg is TickMsg) {
      return (_copy(visible: !visible), null);
    }
    return (this, null);
  }

  @override
  View view() {
    if (!focused) {
      return newView(styles.blurred.render(_char));
    }
    if (!visible) return newView(' ');
    return newView(styles.focused.render(_char));
  }

  CursorModel _copy({
    CursorMode? mode,
    bool? blink,
    bool? visible,
    bool? focused,
    CursorStyles? styles,
  }) =>
      CursorModel(
        mode: mode ?? this.mode,
        blink: blink ?? this.blink,
        visible: visible ?? this.visible,
        focused: focused ?? this.focused,
        styles: styles ?? this.styles,
      );
}
