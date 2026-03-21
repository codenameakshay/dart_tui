/// Minimal ANSI styling helpers (Lip Gloss–style building blocks, very small subset).
abstract final class TuiStyle {
  static const reset = '\x1b[0m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';

  static String fg256(int n) => '\x1b[38;5;${n}m';

  static String fgRgb(int r, int g, int b) => '\x1b[38;2;$r;$g;${b}m';

  static String wrap(String s, {String open = '', String close = reset}) =>
      '$open$s$close';
}
