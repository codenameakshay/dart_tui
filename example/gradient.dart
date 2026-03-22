// ignore_for_file: avoid_print
import 'package:dart_tui/dart_tui.dart';

void main() {
  // Gradient text works by generating per-character ANSI true-color codes —
  // no model loop required. Just call gradientText() and print.

  const reset = '\x1b[0m';
  const bold = '\x1b[1m';

  print('');
  print('$bold  Gradient Text Showcase$reset');
  print('');

  // ── Sunset gradient ─────────────────────────────────────────────────────────
  final sunset = gradientText(
    '  ⬛ Sunset  — hot orange fading to deep violet  ⬛',
    [
      const RgbColor(255, 94, 58), // hot red-orange
      const RgbColor(255, 166, 77), // amber
      const RgbColor(200, 80, 192), // violet
    ],
  );
  print(sunset);
  print('');

  // ── Ocean gradient ────────────────────────────────────────────────────────
  final ocean = gradientText(
    '  ⬛ Ocean   — deep navy rising to aqua-teal     ⬛',
    [
      const RgbColor(10, 30, 120), // deep navy
      const RgbColor(0, 128, 200), // mid blue
      const RgbColor(0, 220, 200), // aqua teal
    ],
  );
  print(ocean);
  print('');

  // ── Catppuccin gradient ───────────────────────────────────────────────────
  final catppuccin = gradientText(
    '  ⬛ Mocha   — Catppuccin Mauve to Sapphire       ⬛',
    [
      const RgbColor(203, 166, 247), // Mauve
      const RgbColor(137, 180, 250), // Blue
      const RgbColor(116, 199, 236), // Sapphire
    ],
  );
  print(catppuccin);
  print('');

  // ── Rainbow ───────────────────────────────────────────────────────────────
  final rainbow = gradientText(
    '  ⬛ Rainbow — the full spectrum in one line      ⬛',
    [
      const RgbColor(255, 0, 0), // red
      const RgbColor(255, 165, 0), // orange
      const RgbColor(255, 255, 0), // yellow
      const RgbColor(0, 200, 0), // green
      const RgbColor(0, 100, 255), // blue
      const RgbColor(148, 0, 211), // violet
    ],
  );
  print(rainbow);
  print('');

  // ── Background gradient ──────────────────────────────────────────────────
  final bgGrad = gradientBackground(
    '  ⬛ BG Grad — background colors, white text      ⬛',
    [
      const RgbColor(30, 30, 80), // dark indigo
      const RgbColor(80, 30, 120), // purple
      const RgbColor(180, 30, 100), // crimson
    ],
    foreground: const Style(foregroundRgb: RgbColor(240, 240, 255)),
  );
  print(bgGrad);
  print('');

  // ── Word-level blend using lighten/darken ────────────────────────────────
  const base = RgbColor(203, 166, 247); // Catppuccin Mauve
  final words = [
    '  100% ',
    ' lighten ',
    '  50%  ',
    ' darken ',
    '  20%  ',
  ];
  final shades = [
    const Style(foregroundRgb: base),
    Style(foregroundRgb: lighten(base, 0.4)),
    Style(foregroundRgb: lighten(base, 0.15)),
    Style(foregroundRgb: darken(base, 0.3)),
    Style(foregroundRgb: darken(base, 0.6)),
  ];
  final shadeRow = StringBuffer('  ⬛ Shades — lighten / darken utilities:  ');
  for (var i = 0; i < words.length; i++) {
    shadeRow.write(shades[i].render(words[i]));
  }
  print(shadeRow.toString());
  print('');
}
