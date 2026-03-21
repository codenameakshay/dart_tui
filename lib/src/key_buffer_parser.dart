import 'package:dart_console/dart_console.dart';

/// Parses [Key]s from a byte buffer (subset of [Console.readKey] behavior).
///
/// Mutates [buffer] only when a full key sequence is recognized.
/// Returns `null` if more bytes are needed (incomplete escape).
Key? parseKeyFromBuffer(List<int> buffer) {
  if (buffer.isEmpty) return null;

  final b0 = buffer[0];

  if (b0 >= 0x01 && b0 <= 0x1a) {
    buffer.removeAt(0);
    return Key.control(ControlCharacter.values[b0]);
  }

  if (b0 == 0x1b) {
    if (buffer.length < 2) return null;
    final b1 = buffer[1];

    if (b1 == 0x5b) {
      if (buffer.length < 3) return null;
      final b2 = buffer[2];
      final arrowOrNav = switch (b2) {
        0x41 => ControlCharacter.arrowUp,
        0x42 => ControlCharacter.arrowDown,
        0x43 => ControlCharacter.arrowRight,
        0x44 => ControlCharacter.arrowLeft,
        0x48 => ControlCharacter.home,
        0x46 => ControlCharacter.end,
        _ => null,
      };
      if (arrowOrNav != null) {
        buffer.removeRange(0, 3);
        return Key.control(arrowOrNav);
      }
      if (b2 >= 0x31 && b2 <= 0x39) {
        if (buffer.length < 4) return null;
        final b3 = buffer[3];
        if (b3 == 0x7e) {
          final d = switch (b2) {
            0x31 => ControlCharacter.home,
            0x33 => ControlCharacter.delete,
            0x34 => ControlCharacter.end,
            0x35 => ControlCharacter.pageUp,
            0x36 => ControlCharacter.pageDown,
            0x37 => ControlCharacter.home,
            0x38 => ControlCharacter.end,
            _ => ControlCharacter.unknown,
          };
          buffer.removeRange(0, 4);
          return Key.control(d);
        }
      }
      buffer.removeRange(0, 3);
      return Key.control(ControlCharacter.unknown);
    }

    if (b1 == 0x4f) {
      if (buffer.length < 3) return null;
      final b2 = buffer[2];
      final fn = switch (b2) {
        0x48 => ControlCharacter.home,
        0x46 => ControlCharacter.end,
        0x50 => ControlCharacter.F1,
        0x51 => ControlCharacter.F2,
        0x52 => ControlCharacter.F3,
        0x53 => ControlCharacter.F4,
        _ => null,
      };
      if (fn != null) {
        buffer.removeRange(0, 3);
        return Key.control(fn);
      }
      buffer.removeRange(0, 3);
      return Key.control(ControlCharacter.unknown);
    }

    if (b1 == 0x62) {
      buffer.removeRange(0, 2);
      return Key.control(ControlCharacter.wordLeft);
    }
    if (b1 == 0x66) {
      buffer.removeRange(0, 2);
      return Key.control(ControlCharacter.wordRight);
    }
    if (b1 == 0x7f) {
      buffer.removeRange(0, 2);
      return Key.control(ControlCharacter.wordBackspace);
    }

    buffer.removeRange(0, 2);
    return Key.control(ControlCharacter.unknown);
  }

  if (b0 == 0x7f) {
    buffer.removeAt(0);
    return Key.control(ControlCharacter.backspace);
  }

  if (b0 == 0x00 || (b0 >= 0x1c && b0 <= 0x1f)) {
    buffer.removeAt(0);
    return Key.control(ControlCharacter.unknown);
  }

  buffer.removeAt(0);
  return Key.printable(String.fromCharCode(b0));
}
