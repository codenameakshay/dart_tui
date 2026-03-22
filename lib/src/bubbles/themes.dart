import 'style.dart';

/// A named collection of [Style] presets for common semantic roles.
///
/// Use the built-in themes ([catppuccin], [nord], [dracula]) or construct
/// your own. Component `XxxStyles.defaults` are pre-wired with
/// [catppuccin] colors so you get beautiful output out of the box — no
/// configuration required.
final class Theme {
  const Theme({
    required this.name,
    required this.base,
    required this.muted,
    required this.accent,
    required this.highlight,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
    required this.focusBorder,
  });

  final String name;

  /// Normal body text.
  final Style base;

  /// Secondary / dimmed text.
  final Style muted;

  /// Active item, cursor, selection highlight foreground.
  final Style accent;

  /// Selected row / active tab background.
  final Style highlight;

  final Style success;
  final Style warning;
  final Style error;

  /// Unfocused container border.
  final Style border;

  /// Focused container border (accent color).
  final Style focusBorder;

  // ── Built-in themes ──────────────────────────────────────────────────────

  /// Catppuccin Mocha — dark, soft purples. This is the default theme used
  /// by all component `*.defaults` style constants.
  static const Theme catppuccin = Theme(
    name: 'catppuccin',
    base: Style(
      foregroundRgb: RgbColor(205, 214, 244), // #CDD6F4 Text
      backgroundRgb: RgbColor(30, 30, 46), // #1E1E2E Base
    ),
    muted: Style(
      foregroundRgb: RgbColor(166, 173, 200), // #A6ADC8 Subtext0
      isDim: true,
    ),
    accent: Style(
      foregroundRgb: RgbColor(203, 166, 247), // #CBA6F7 Mauve
      isBold: true,
    ),
    highlight: Style(
      backgroundRgb: RgbColor(49, 50, 68), // #313244 Surface0
    ),
    success: Style(foregroundRgb: RgbColor(166, 227, 161)), // #A6E3A1 Green
    warning: Style(foregroundRgb: RgbColor(249, 226, 175)), // #F9E2AF Yellow
    error: Style(foregroundRgb: RgbColor(243, 139, 168)), // #F38BA8 Red
    border: Style(
      foregroundRgb: RgbColor(88, 91, 112), // #585B70 Surface2
      border: Border.rounded,
    ),
    focusBorder: Style(
      foregroundRgb: RgbColor(203, 166, 247), // #CBA6F7 Mauve
      border: Border.rounded,
    ),
  );

  /// Nord — cool arctic blues.
  static const Theme nord = Theme(
    name: 'nord',
    base: Style(
      foregroundRgb: RgbColor(236, 239, 244), // #ECEFF4 Nord6
      backgroundRgb: RgbColor(46, 52, 64), // #2E3440 Nord0
    ),
    muted: Style(
      foregroundRgb: RgbColor(76, 86, 106), // #4C566A Nord3
      isDim: true,
    ),
    accent: Style(
      foregroundRgb: RgbColor(136, 192, 208), // #88C0D0 Nord8 Frost
      isBold: true,
    ),
    highlight: Style(
      backgroundRgb: RgbColor(59, 66, 82), // #3B4252 Nord1
    ),
    success: Style(foregroundRgb: RgbColor(163, 190, 140)), // #A3BE8C Nord14
    warning: Style(foregroundRgb: RgbColor(235, 203, 139)), // #EBCB8B Nord13
    error: Style(foregroundRgb: RgbColor(191, 97, 106)), // #BF616A Nord11
    border: Style(
      foregroundRgb: RgbColor(76, 86, 106), // #4C566A Nord3
      border: Border.box,
    ),
    focusBorder: Style(
      foregroundRgb: RgbColor(136, 192, 208), // #88C0D0 Nord8
      border: Border.box,
    ),
  );

  /// Dracula — vivid purples and vibrant accents.
  static const Theme dracula = Theme(
    name: 'dracula',
    base: Style(
      foregroundRgb: RgbColor(248, 248, 242), // #F8F8F2 Foreground
      backgroundRgb: RgbColor(40, 42, 54), // #282A36 Background
    ),
    muted: Style(
      foregroundRgb: RgbColor(98, 114, 164), // #6272A4 Comment
      isDim: true,
    ),
    accent: Style(
      foregroundRgb: RgbColor(189, 147, 249), // #BD93F9 Purple
      isBold: true,
    ),
    highlight: Style(
      backgroundRgb: RgbColor(68, 71, 90), // #44475A Current Line
    ),
    success: Style(foregroundRgb: RgbColor(80, 250, 123)), // #50FA7B Green
    warning: Style(foregroundRgb: RgbColor(255, 184, 108)), // #FFB86C Orange
    error: Style(foregroundRgb: RgbColor(255, 85, 85)), // #FF5555 Red
    border: Style(
      foregroundRgb: RgbColor(98, 114, 164), // #6272A4 Comment
      border: Border.rounded,
    ),
    focusBorder: Style(
      foregroundRgb: RgbColor(189, 147, 249), // #BD93F9 Purple
      border: Border.rounded,
    ),
  );

  /// Alias for [catppuccin] — the default theme applied to all component styles.
  static const Theme defaultTheme = catppuccin;
}
