/// Builds an OSC 0 window-title sequence after removing terminal controls.
///
/// C0, DEL, and C1 code points can terminate an OSC payload or start another
/// terminal command. Printable Unicode is preserved unchanged.
String windowTitleSequence(String title) {
  return '\x1b]0;${sanitizeOscText(title)}\x07';
}

/// Removes terminal controls and string terminators from an OSC text field.
String sanitizeOscText(String value) {
  final safe = StringBuffer();
  final codePoints = value.runes.toList();
  for (var index = 0; index < codePoints.length; index++) {
    final codePoint = codePoints[index];
    if (codePoint == 0x1b &&
        index + 1 < codePoints.length &&
        codePoints[index + 1] == 0x5c) {
      index++;
      continue;
    }
    final isC0 = codePoint <= 0x1f;
    final isDelOrC1 = codePoint >= 0x7f && codePoint <= 0x9f;
    if (!isC0 && !isDelOrC1) safe.writeCharCode(codePoint);
  }
  return safe.toString();
}
