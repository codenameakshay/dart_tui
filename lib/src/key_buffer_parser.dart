import 'dart:convert';
import 'msg.dart';

/// Parses [TeaKey]s from a byte buffer, covering the control-character and
/// simple-escape-sequence subset of terminal input that isn't claimed by the
/// CSI/OSC/DCS decoder in [TerminalInputDecoder].
///
/// Mutates [buffer] only when a full key sequence is recognised.
/// Returns `null` if more bytes are needed (incomplete escape sequence).
TeaKey? parseKeyFromBuffer(List<int> buffer) {
  final parsed = parseKeyFromBufferAt(buffer, 0);
  if (parsed == null) return null;
  buffer.removeRange(0, parsed.consumed);
  return parsed.key;
}

/// Parses a key without moving bytes in [buffer]. The returned record contains
/// the key and number of bytes consumed from [offset]. This lets the streaming
/// decoder keep a read cursor instead of shifting the whole buffer per key.
({TeaKey key, int consumed})? parseKeyFromBufferAt(
  List<int> buffer,
  int offset,
) {
  final length = buffer.length - offset;
  if (length <= 0) return null;

  final b0 = buffer[offset];

  // Control characters 0x01–0x1a (Ctrl+A … Ctrl+Z)
  if (b0 >= 0x01 && b0 <= 0x1a) {
    return (
      key: switch (b0) {
        0x09 => const TeaKey(code: KeyCode.tab), // HT / Tab
        0x0a => const TeaKey(code: KeyCode.enter), // LF / Enter (Linux/WSL)
        0x0d => const TeaKey(code: KeyCode.enter), // CR / Enter
        _ => TeaKey(
            code: KeyCode.rune,
            // 0x01→'a', 0x02→'b', … 0x1a→'z'
            text: String.fromCharCode(b0 + 0x60),
            modifiers: const {KeyMod.ctrl},
          ),
      },
      consumed: 1
    );
  }

  // Escape sequences
  if (b0 == 0x1b) {
    if (length < 2) return null;
    final b1 = buffer[offset + 1];

    // CSI: ESC [
    if (b1 == 0x5b) {
      if (length < 3) return null;
      final b2 = buffer[offset + 2];
      final arrowOrNav = switch (b2) {
        0x41 => const TeaKey(code: KeyCode.up),
        0x42 => const TeaKey(code: KeyCode.down),
        0x43 => const TeaKey(code: KeyCode.right),
        0x44 => const TeaKey(code: KeyCode.left),
        0x48 => const TeaKey(code: KeyCode.home),
        0x46 => const TeaKey(code: KeyCode.end),
        // CSI Z is backtab (Shift+Tab); surface it as Tab + Shift so consumers
        // (e.g. TabsModel's `case 'shift+tab'`) receive `key == 'shift+tab'`.
        0x5a => const TeaKey(code: KeyCode.tab, modifiers: {KeyMod.shift}),
        _ => null,
      };
      if (arrowOrNav != null) {
        return (key: arrowOrNav, consumed: 3);
      }
      // ESC [ n ~  (delete, pgup, pgdn, home, end)
      if (b2 >= 0x31 && b2 <= 0x39) {
        if (length < 4) return null;
        final b3 = buffer[offset + 3];
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
          return (key: key, consumed: 4);
        }
      }
      return (key: const TeaKey(code: KeyCode.unknown), consumed: 3);
    }

    // SS3: ESC O  (home, end, F1–F4)
    if (b1 == 0x4f) {
      if (length < 3) return null;
      final b2 = buffer[offset + 2];
      final key = switch (b2) {
        0x48 => const TeaKey(code: KeyCode.home),
        0x46 => const TeaKey(code: KeyCode.end),
        0x50 => const TeaKey(code: KeyCode.f1),
        0x51 => const TeaKey(code: KeyCode.f2),
        0x52 => const TeaKey(code: KeyCode.f3),
        0x53 => const TeaKey(code: KeyCode.f4),
        _ => null,
      };
      return (key: key ?? const TeaKey(code: KeyCode.unknown), consumed: 3);
    }

    // Alt+Left: ESC b
    if (b1 == 0x62) {
      return (
        key: const TeaKey(code: KeyCode.left, modifiers: {KeyMod.alt}),
        consumed: 2
      );
    }
    // Alt+Right: ESC f
    if (b1 == 0x66) {
      return (
        key: const TeaKey(code: KeyCode.right, modifiers: {KeyMod.alt}),
        consumed: 2
      );
    }
    // Alt+Backspace: ESC DEL
    if (b1 == 0x7f) {
      return (
        key: const TeaKey(code: KeyCode.backspace, modifiers: {KeyMod.alt}),
        consumed: 2
      );
    }

    return (key: const TeaKey(code: KeyCode.unknown), consumed: 2);
  }

  // DEL / Backspace
  if (b0 == 0x7f) {
    return (key: const TeaKey(code: KeyCode.backspace), consumed: 1);
  }

  // Other non-printable controls
  if (b0 == 0x00 || (b0 >= 0x1c && b0 <= 0x1f)) {
    return (key: const TeaKey(code: KeyCode.unknown), consumed: 1);
  }

  if (b0 < 0x80) {
    return (
      key: TeaKey(code: KeyCode.rune, text: String.fromCharCode(b0)),
      consumed: 1,
    );
  }

  final expectedLength = switch (b0) {
    >= 0xc2 && <= 0xdf => 2,
    >= 0xe0 && <= 0xef => 3,
    >= 0xf0 && <= 0xf4 => 4,
    _ => 0,
  };
  if (expectedLength == 0) {
    return (key: const TeaKey(code: KeyCode.unknown), consumed: 1);
  }

  final availableContinuationBytes =
      length - 1 < expectedLength - 1 ? length - 1 : expectedLength - 1;
  for (var index = 1; index <= availableContinuationBytes; index++) {
    final byte = buffer[offset + index];
    if (byte < 0x80 || byte > 0xbf) {
      return (key: const TeaKey(code: KeyCode.unknown), consumed: 1);
    }
    if (index == 1 &&
        ((b0 == 0xe0 && byte < 0xa0) ||
            (b0 == 0xed && byte > 0x9f) ||
            (b0 == 0xf0 && byte < 0x90) ||
            (b0 == 0xf4 && byte > 0x8f))) {
      return (key: const TeaKey(code: KeyCode.unknown), consumed: 1);
    }
  }
  if (length < expectedLength) return null;

  try {
    final decoded = utf8.decode(
      buffer.sublist(offset, offset + expectedLength),
    );
    return (
      key: TeaKey(code: KeyCode.rune, text: decoded),
      consumed: expectedLength
    );
  } on FormatException {
    return (key: const TeaKey(code: KeyCode.unknown), consumed: 1);
  }
}
