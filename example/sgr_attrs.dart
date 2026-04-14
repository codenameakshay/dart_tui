// SGR text attribute showcase — reverse, blink, overline, inherit.
// Run: fvm dart run example/sgr_attrs.dart

// ignore_for_file: avoid_print
import 'package:dart_tui/dart_tui.dart';

void main() {
  const reset = '\x1b[0m';
  const bold = '\x1b[1m';

  print('');
  print('$bold  SGR Attribute Showcase$reset');
  print('');

  // ── Core SGR attributes ────────────────────────────────────────────────────
  final attrs = <(String, Style)>[
    ('bold', const Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true)),
    ('dim', const Style(foregroundRgb: RgbColor(205, 214, 244), isDim: true)),
    (
      'italic',
      const Style(foregroundRgb: RgbColor(137, 180, 250), isItalic: true)
    ),
    (
      'underline',
      const Style(foregroundRgb: RgbColor(166, 227, 161), isUnderline: true)
    ),
    (
      'strikethrough',
      const Style(foregroundRgb: RgbColor(243, 139, 168), isStrikethrough: true)
    ),
    (
      'reverse',
      const Style(
          foregroundRgb: RgbColor(30, 30, 46),
          backgroundRgb: RgbColor(203, 166, 247),
          isReverse: true)
    ),
    (
      'blink',
      const Style(foregroundRgb: RgbColor(249, 226, 175), isBlink: true)
    ),
    (
      'overline',
      const Style(foregroundRgb: RgbColor(116, 199, 236), isOverline: true)
    ),
  ];

  for (final (name, style) in attrs) {
    final label = name.padRight(15);
    print('  ${style.render(label)}  ($name)');
  }
  print('');

  // ── Style.inherit() ────────────────────────────────────────────────────────
  print('$bold  Style inheritance (child inherits parent attrs):$reset');
  print('');
  const parent = Style(
    foregroundRgb: RgbColor(203, 166, 247),
    isBold: true,
    isItalic: true,
  );
  const child = Style(
    foregroundRgb: RgbColor(166, 227, 161), // overrides fg
    // isBold and isItalic inherited from parent
  );
  final resolved = child.inherit(parent);
  print('  Parent: ${parent.render('bold + italic + mauve')}');
  print('  Child (fg only): ${child.render('just green')}');
  print('  Child.inherit(parent): ${resolved.render('bold + italic + green')}');
  print('');

  // ── Combined attributes ────────────────────────────────────────────────────
  print('$bold  Combined: bold + italic + underline + overline:$reset');
  print('');
  print(const Style(
    foregroundRgb: RgbColor(249, 226, 175),
    isBold: true,
    isItalic: true,
    isUnderline: true,
    isOverline: true,
  ).render('  All four at once!'));
  print('');
}
