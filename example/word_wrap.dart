// Word-wrap demonstration — shows Style.wordWrap with padding and borders.
// Run: fvm dart run example/word_wrap.dart

// ignore_for_file: avoid_print
import 'package:dart_tui/dart_tui.dart';

void main() {
  const reset = '\x1b[0m';
  const bold = '\x1b[1m';

  print('');
  print('$bold  Word-Wrap Showcase$reset');
  print('');

  const longText = 'The quick brown fox jumps over the lazy dog. '
      'This sentence is long enough to demonstrate wrapping behaviour '
      'at different column widths.';

  // ── No wrap (default) ────────────────────────────────────────────────────
  print('$bold  Plain (no wrap):$reset');
  print(const Style(
    foregroundRgb: RgbColor(205, 214, 244),
    padding: EdgeInsets.all(1),
    border: Border.box,
    borderForeground: RgbColor(88, 91, 112),
  ).render(longText));
  print('');

  // ── Word-wrap at 40 columns ───────────────────────────────────────────────
  print('$bold  Wrapped at 40 columns (with padding):$reset');
  print(const Style(
    foregroundRgb: RgbColor(203, 166, 247),
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 1),
    border: Border.box,
    borderForeground: RgbColor(203, 166, 247),
    wordWrap: true,
    width: 42,
  ).render(longText));
  print('');

  // ── Word-wrap at 30 columns with rounded border ───────────────────────────
  print('$bold  Wrapped at 30 columns (rounded border, bold):$reset');
  print(const Style(
    foregroundRgb: RgbColor(166, 227, 161),
    isBold: true,
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 1),
    border: Border.rounded,
    borderForeground: RgbColor(166, 227, 161),
    wordWrap: true,
    width: 32,
  ).render(longText));
  print('');

  // ── Thick border with border title ─────────────────────────────────────────
  print('$bold  Wrapped + border title:$reset');
  print(const Style(
    foregroundRgb: RgbColor(137, 180, 250),
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 1),
    border: Border.thick,
    borderForeground: RgbColor(137, 180, 250),
    borderTitle: ' Word Wrap ',
    borderTitleAlignment: Align.center,
    wordWrap: true,
    width: 44,
  ).render(longText));
  print('');
}
