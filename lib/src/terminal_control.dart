/// Builds an OSC 0 window-title sequence after removing terminal controls.
///
/// C0, DEL, and C1 code points can terminate an OSC payload or start another
/// terminal command. Printable Unicode is preserved unchanged.
String windowTitleSequence(String title) {
  final safeTitle = StringBuffer();
  for (final codePoint in title.runes) {
    final isC0 = codePoint <= 0x1f;
    final isDelOrC1 = codePoint >= 0x7f && codePoint <= 0x9f;
    if (!isC0 && !isDelOrC1) safeTitle.writeCharCode(codePoint);
  }
  return '\x1b]0;$safeTitle\x07';
}
