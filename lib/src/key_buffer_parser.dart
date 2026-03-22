import 'msg.dart';

/// Parses [TeaKey]s from a byte buffer, covering the control-character and
/// simple-escape-sequence subset of terminal input that isn't claimed by the
/// CSI/OSC/DCS decoder in [TerminalInputDecoder].
///
/// Mutates [buffer] only when a full key sequence is recognised.
/// Returns `null` if more bytes are needed (incomplete escape sequence).
TeaKey? parseKeyFromBuffer(List<int> buffer) {
  if (buffer.isEmpty) return null;

  final b0 = buffer[0];

  // Control characters 0x01–0x1a (Ctrl+A … Ctrl+Z)
  if (b0 >= 0x01 && b0 <= 0x1a) {
    buffer.removeAt(0);
    return switch (b0) {
      0x09 => const TeaKey(code: KeyCode.tab), // HT / Tab
      0x0a => const TeaKey(code: KeyCode.enter), // LF / Enter (Linux/WSL)
      0x0d => const TeaKey(code: KeyCode.enter), // CR / Enter
      _ => TeaKey(
          code: KeyCode.rune,
          // 0x01→'a', 0x02→'b', … 0x1a→'z'
          text: String.fromCharCode(b0 + 0x60),
          modifiers: const {KeyMod.ctrl},
        ),
    };
  }

  // Escape sequences
  if (b0 == 0x1b) {
    if (buffer.length < 2) return null;
    final b1 = buffer[1];

    // CSI: ESC [
    if (b1 == 0x5b) {
      if (buffer.length < 3) return null;
      final b2 = buffer[2];
      final arrowOrNav = switch (b2) {
        0x41 => const TeaKey(code: KeyCode.up),
        0x42 => const TeaKey(code: KeyCode.down),
        0x43 => const TeaKey(code: KeyCode.right),
        0x44 => const TeaKey(code: KeyCode.left),
        0x48 => const TeaKey(code: KeyCode.home),
        0x46 => const TeaKey(code: KeyCode.end),
        _ => null,
      };
      if (arrowOrNav != null) {
        buffer.removeRange(0, 3);
        return arrowOrNav;
      }
      // ESC [ n ~  (delete, pgup, pgdn, home, end)
      if (b2 >= 0x31 && b2 <= 0x39) {
        if (buffer.length < 4) return null;
        final b3 = buffer[3];
        if (b3 == 0x7e) {
          final key = switch (b2) {
            0x31 => const TeaKey(code: KeyCode.home),
            0x33 => const TeaKey(code: KeyCode.delete),
            0x34 => const TeaKey(code: KeyCode.end),
            0x35 => const TeaKey(code: KeyCode.pageUp),
            0x36 => const TeaKey(code: KeyCode.pageDown),
            0x37 => const TeaKey(code: KeyCode.home),
            0x38 => const TeaKey(code: KeyCode.end),
            _ => const TeaKey(code: KeyCode.unknown),
          };
          buffer.removeRange(0, 4);
          return key;
        }
      }
      buffer.removeRange(0, 3);
      return const TeaKey(code: KeyCode.unknown);
    }

    // SS3: ESC O  (home, end, F1–F4)
    if (b1 == 0x4f) {
      if (buffer.length < 3) return null;
      final b2 = buffer[2];
      final key = switch (b2) {
        0x48 => const TeaKey(code: KeyCode.home),
        0x46 => const TeaKey(code: KeyCode.end),
        0x50 => const TeaKey(code: KeyCode.f1),
        0x51 => const TeaKey(code: KeyCode.f2),
        0x52 => const TeaKey(code: KeyCode.f3),
        0x53 => const TeaKey(code: KeyCode.f4),
        _ => null,
      };
      buffer.removeRange(0, 3);
      return key ?? const TeaKey(code: KeyCode.unknown);
    }

    // Alt+Left: ESC b
    if (b1 == 0x62) {
      buffer.removeRange(0, 2);
      return const TeaKey(code: KeyCode.left, modifiers: {KeyMod.alt});
    }
    // Alt+Right: ESC f
    if (b1 == 0x66) {
      buffer.removeRange(0, 2);
      return const TeaKey(code: KeyCode.right, modifiers: {KeyMod.alt});
    }
    // Alt+Backspace: ESC DEL
    if (b1 == 0x7f) {
      buffer.removeRange(0, 2);
      return const TeaKey(code: KeyCode.backspace, modifiers: {KeyMod.alt});
    }

    buffer.removeRange(0, 2);
    return const TeaKey(code: KeyCode.unknown);
  }

  // DEL / Backspace
  if (b0 == 0x7f) {
    buffer.removeAt(0);
    return const TeaKey(code: KeyCode.backspace);
  }

  // Other non-printable controls
  if (b0 == 0x00 || (b0 >= 0x1c && b0 <= 0x1f)) {
    buffer.removeAt(0);
    return const TeaKey(code: KeyCode.unknown);
  }

  // Printable ASCII / Latin-1
  buffer.removeAt(0);
  return TeaKey(code: KeyCode.rune, text: String.fromCharCode(b0));
}
