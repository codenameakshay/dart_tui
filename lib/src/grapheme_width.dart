import 'package:characters/characters.dart';

/// Returns the number of terminal cells occupied by one grapheme cluster.
int graphemeWidth(String grapheme) {
  if (grapheme.isEmpty) return 0;

  final runes = grapheme.runes.toList(growable: false);
  if (runes.every(_isZeroWidth)) return 0;

  if (runes.contains(0xfe0f) ||
      runes.contains(0x20e3) ||
      runes.any(_isRegionalIndicator) ||
      runes.any(_isEmoji) ||
      runes.any(_isEastAsianWide)) {
    return 2;
  }

  return 1;
}

/// Returns the terminal-cell width of [text], measured by grapheme cluster.
int textWidth(String text) {
  var width = 0;
  for (final grapheme in text.characters) {
    width += graphemeWidth(grapheme);
  }
  return width;
}

bool _isZeroWidth(int rune) =>
    rune == 0x200c ||
    rune == 0x200d ||
    (rune >= 0x0000 && rune <= 0x001f) ||
    (rune >= 0x007f && rune <= 0x009f) ||
    (rune >= 0x0300 && rune <= 0x036f) ||
    (rune >= 0x0483 && rune <= 0x0489) ||
    (rune >= 0x0591 && rune <= 0x05bd) ||
    rune == 0x05bf ||
    (rune >= 0x05c1 && rune <= 0x05c2) ||
    (rune >= 0x0610 && rune <= 0x061a) ||
    (rune >= 0x064b && rune <= 0x065f) ||
    rune == 0x0670 ||
    (rune >= 0x06d6 && rune <= 0x06ed) ||
    (rune >= 0x0900 && rune <= 0x0902) ||
    rune == 0x093a ||
    rune == 0x093c ||
    (rune >= 0x0941 && rune <= 0x0948) ||
    (rune >= 0x0951 && rune <= 0x0957) ||
    (rune >= 0x1ab0 && rune <= 0x1aff) ||
    (rune >= 0x1dc0 && rune <= 0x1dff) ||
    (rune >= 0x20d0 && rune <= 0x20ff) ||
    (rune >= 0xfe00 && rune <= 0xfe0f) ||
    (rune >= 0xfe20 && rune <= 0xfe2f) ||
    (rune >= 0xe0100 && rune <= 0xe01ef) ||
    (rune >= 0x1f3fb && rune <= 0x1f3ff);

bool _isRegionalIndicator(int rune) => rune >= 0x1f1e6 && rune <= 0x1f1ff;

bool _isEmoji(int rune) =>
    rune == 0x00a9 ||
    rune == 0x00ae ||
    rune == 0x203c ||
    rune == 0x2049 ||
    rune == 0x2122 ||
    rune == 0x2139 ||
    (rune >= 0x2194 && rune <= 0x2199) ||
    (rune >= 0x21a9 && rune <= 0x21aa) ||
    (rune >= 0x231a && rune <= 0x231b) ||
    rune == 0x2328 ||
    rune == 0x23cf ||
    (rune >= 0x23e9 && rune <= 0x23f3) ||
    (rune >= 0x23f8 && rune <= 0x23fa) ||
    (rune >= 0x25aa && rune <= 0x25ab) ||
    (rune >= 0x25b6 && rune <= 0x25c0) ||
    (rune >= 0x25fb && rune <= 0x25fe) ||
    (rune >= 0x2600 && rune <= 0x27bf) ||
    (rune >= 0x2934 && rune <= 0x2935) ||
    (rune >= 0x2b05 && rune <= 0x2b55) ||
    (rune >= 0x3030 && rune <= 0x303d) ||
    (rune >= 0x3297 && rune <= 0x3299) ||
    (rune >= 0x1f000 && rune <= 0x1faff);

bool _isEastAsianWide(int rune) =>
    rune >= 0x1100 &&
    (rune <= 0x115f ||
        rune == 0x2329 ||
        rune == 0x232a ||
        (rune >= 0x2e80 && rune <= 0xa4cf && rune != 0x303f) ||
        (rune >= 0xac00 && rune <= 0xd7a3) ||
        (rune >= 0xf900 && rune <= 0xfaff) ||
        (rune >= 0xfe10 && rune <= 0xfe19) ||
        (rune >= 0xfe30 && rune <= 0xfe6f) ||
        (rune >= 0xff00 && rune <= 0xff60) ||
        (rune >= 0xffe0 && rune <= 0xffe6) ||
        (rune >= 0x20000 && rune <= 0x3fffd));
