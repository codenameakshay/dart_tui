// Border style showcase — demonstrates border types, titles, and colors.
// Run: fvm dart run example/border_style.dart

// ignore_for_file: avoid_print
import 'package:dart_tui/dart_tui.dart';

void main() {
  const reset = '\x1b[0m';
  const bold = '\x1b[1m';
  const content = ' Hello, borders! ';

  print('');
  print('$bold  Border Style Showcase$reset');
  print('');

  // ── All built-in border types ─────────────────────────────────────────────
  final types = <(String, Border)>[
    ('box', Border.box),
    ('rounded', Border.rounded),
    ('thick', Border.thick),
    // ignore: deprecated_member_use
    ('double', Border.double),
    ('hidden', Border.hidden),
    ('none', Border.none),
  ];

  for (final (name, border) in types) {
    final rendered = Style(
      foregroundRgb: const RgbColor(205, 214, 244),
      border: border,
      borderForeground: const RgbColor(137, 180, 250),
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 1),
    ).render(content);
    print('$bold  $name:$reset');
    print(rendered);
    print('');
  }

  // ── Border with foreground + background color ─────────────────────────────
  print('$bold  Colored border (mauve fg, surface bg):$reset');
  print(const Style(
    foregroundRgb: RgbColor(205, 214, 244),
    border: Border.rounded,
    borderForeground: RgbColor(203, 166, 247),
    borderBackground: RgbColor(30, 30, 46),
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 1),
  ).render(content));
  print('');

  // ── Border title alignments ───────────────────────────────────────────────
  print('$bold  Border titles (left / center / right):$reset');
  for (final (label, align) in [
    ('left', Align.left),
    ('center', Align.center),
    ('right', Align.right),
  ]) {
    final rendered = Style(
      foregroundRgb: const RgbColor(205, 214, 244),
      border: Border.rounded,
      borderForeground: const RgbColor(166, 227, 161),
      borderTitle: ' $label title ',
      borderTitleAlignment: align,
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 1),
      width: 36,
    ).render(content);
    print(rendered);
  }
  print('');
}
