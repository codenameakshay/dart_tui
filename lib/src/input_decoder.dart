import 'dart:convert';

import 'key_buffer_parser.dart';
import 'msg.dart';

final class TerminalInputDecoder {
  final List<int> _buffer = <int>[];
  final StringBuffer _pasteBuffer = StringBuffer();
  bool _inPaste = false;

  List<Msg> feed(List<int> data) {
    _buffer.addAll(data);
    final out = <Msg>[];

    while (true) {
      if (_inPaste) {
        final endMatch = _matchesPrefix(_buffer, _pasteEnd);
        if (endMatch == _PrefixMatch.partial) break;
        if (endMatch == _PrefixMatch.full) {
          _consume(_pasteEnd.length);
          out.add(PasteMsg(_pasteBuffer.toString()));
          out.add(PasteEndMsg());
          _pasteBuffer.clear();
          _inPaste = false;
          continue;
        }

        if (_buffer.isEmpty) break;
        _pasteBuffer.writeCharCode(_buffer.removeAt(0));
        continue;
      }

      final pasteStartMatch = _matchesPrefix(_buffer, _pasteStart);
      if (pasteStartMatch == _PrefixMatch.partial) break;
      if (pasteStartMatch == _PrefixMatch.full) {
        _consume(_pasteStart.length);
        _inPaste = true;
        out.add(PasteStartMsg());
        continue;
      }

      final focusInMatch = _matchesPrefix(_buffer, _focusIn);
      if (focusInMatch == _PrefixMatch.partial) break;
      if (focusInMatch == _PrefixMatch.full) {
        _consume(_focusIn.length);
        out.add(FocusMsg());
        continue;
      }

      final focusOutMatch = _matchesPrefix(_buffer, _focusOut);
      if (focusOutMatch == _PrefixMatch.partial) break;
      if (focusOutMatch == _PrefixMatch.full) {
        _consume(_focusOut.length);
        out.add(BlurMsg());
        continue;
      }

      final osc = _tryParseOsc(_buffer);
      if (osc == _ParseState.partial) break;
      if (osc case _ParsedMessages(:final consumed, :final msgs)) {
        _consume(consumed);
        out.addAll(msgs);
        continue;
      }

      final dcs = _tryParseDcs(_buffer);
      if (dcs == _ParseState.partial) break;
      if (dcs case _ParsedMessages(:final consumed, :final msgs)) {
        _consume(consumed);
        out.addAll(msgs);
        continue;
      }

      final csi = _tryParseCsi(_buffer);
      if (csi == _ParseState.partial) break;
      if (csi case _ParsedMessages(:final consumed, :final msgs)) {
        _consume(consumed);
        out.addAll(msgs);
        continue;
      }

      final TeaKey? key = parseKeyFromBuffer(_buffer);
      if (key != null) {
        out.add(KeyPressMsg(key));
        continue;
      }

      break;
    }

    return out;
  }

  void _consume(int count) {
    _buffer.removeRange(0, count);
  }
}

const List<int> _pasteStart = <int>[0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e];
const List<int> _pasteEnd = <int>[0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e];
const List<int> _focusIn = <int>[0x1b, 0x5b, 0x49];
const List<int> _focusOut = <int>[0x1b, 0x5b, 0x4f];

sealed class _ParseResult {
  const _ParseResult();
}

final class _ParseState extends _ParseResult {
  const _ParseState._(this.kind);
  final int kind;

  static const _ParseState none = _ParseState._(0);
  static const _ParseState partial = _ParseState._(1);
}

final class _ParsedMessages extends _ParseResult {
  const _ParsedMessages({
    required this.consumed,
    required this.msgs,
  });

  final int consumed;
  final List<Msg> msgs;
}

enum _PrefixMatch {
  none,
  partial,
  full,
}

_PrefixMatch _matchesPrefix(List<int> buffer, List<int> seq) {
  final len = buffer.length < seq.length ? buffer.length : seq.length;
  for (var i = 0; i < len; i++) {
    if (buffer[i] != seq[i]) return _PrefixMatch.none;
  }
  if (buffer.length < seq.length) return _PrefixMatch.partial;
  return _PrefixMatch.full;
}

_ParseResult _tryParseCsi(List<int> buffer) {
  if (buffer.length < 2) return _ParseState.none;
  if (buffer[0] != 0x1b || buffer[1] != 0x5b) return _ParseState.none;

  var i = 2;
  while (i < buffer.length) {
    final b = buffer[i];
    if (b >= 0x40 && b <= 0x7e) {
      final seq = String.fromCharCodes(buffer.sublist(2, i + 1));
      final msgs = _decodeCsi(seq);
      if (msgs.isEmpty) return _ParseState.none;
      return _ParsedMessages(consumed: i + 1, msgs: msgs);
    }
    i++;
  }
  return _ParseState.partial;
}

List<Msg> _decodeCsi(String seq) {
  if (seq.endsWith('R')) {
    final body = seq.substring(0, seq.length - 1);
    final parts = body.split(';');
    if (parts.length == 2) {
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row != null && col != null) {
        return [
          CursorPositionMsg(
            x: col > 0 ? col - 1 : 0,
            y: row > 0 ? row - 1 : 0,
          ),
        ];
      }
    }
    return const <Msg>[];
  }

  if (seq.endsWith('\$y')) {
    final body = seq.substring(0, seq.length - 2).replaceFirst('?', '');
    final parts = body.split(';');
    if (parts.length == 2) {
      final mode = int.tryParse(parts[0]);
      final value = int.tryParse(parts[1]);
      if (mode != null && value != null) {
        final msgs = <Msg>[ModeReportMsg(mode: mode, value: value)];
        if (mode == 2027) {
          msgs.add(KeyboardEnhancementsMsg(value));
        }
        return msgs;
      }
    }
    return const <Msg>[];
  }

  if (seq.startsWith('>') && seq.endsWith('c')) {
    return [TerminalVersionMsg(seq.substring(1, seq.length - 1))];
  }

  if (seq.startsWith('<') && (seq.endsWith('M') || seq.endsWith('m'))) {
    final release = seq.endsWith('m');
    final body = seq.substring(1, seq.length - 1);
    final parts = body.split(';');
    if (parts.length == 3) {
      final cb = int.tryParse(parts[0]);
      final cx = int.tryParse(parts[1]);
      final cy = int.tryParse(parts[2]);
      if (cb != null && cx != null && cy != null) {
        final mouse = Mouse(
          x: cx > 0 ? cx - 1 : 0,
          y: cy > 0 ? cy - 1 : 0,
          button: _mouseButtonFromCb(cb),
          modifiers: _mouseModifiersFromCb(cb),
        );
        if ((cb & 64) != 0) {
          return [MouseWheelMsg(mouse)];
        }
        if ((cb & 32) != 0 && !release) {
          return [MouseMotionMsg(mouse)];
        }
        if (release) {
          return [MouseReleaseMsg(mouse)];
        }
        return [MouseClickMsg(mouse)];
      }
    }
  }

  return const <Msg>[];
}

_ParseResult _tryParseOsc(List<int> buffer) {
  if (buffer.length < 2) return _ParseState.none;
  if (buffer[0] != 0x1b || buffer[1] != 0x5d) return _ParseState.none;

  var i = 2;
  while (i < buffer.length) {
    final b = buffer[i];
    if (b == 0x07) {
      final seq = String.fromCharCodes(buffer.sublist(2, i));
      return _ParsedMessages(consumed: i + 1, msgs: _decodeOsc(seq));
    }
    if (b == 0x1b) {
      if (i + 1 >= buffer.length) return _ParseState.partial;
      if (buffer[i + 1] == 0x5c) {
        final seq = String.fromCharCodes(buffer.sublist(2, i));
        return _ParsedMessages(consumed: i + 2, msgs: _decodeOsc(seq));
      }
    }
    i++;
  }
  return _ParseState.partial;
}

_ParseResult _tryParseDcs(List<int> buffer) {
  if (buffer.length < 2) return _ParseState.none;
  if (buffer[0] != 0x1b || buffer[1] != 0x50) return _ParseState.none;

  var i = 2;
  while (i < buffer.length) {
    final b = buffer[i];
    if (b == 0x1b) {
      if (i + 1 >= buffer.length) return _ParseState.partial;
      if (buffer[i + 1] == 0x5c) {
        final seq = String.fromCharCodes(buffer.sublist(2, i));
        return _ParsedMessages(consumed: i + 2, msgs: _decodeDcs(seq));
      }
    }
    i++;
  }
  return _ParseState.partial;
}

List<Msg> _decodeDcs(String seq) {
  final marker = seq.indexOf('+r');
  if (marker == -1) return const <Msg>[];
  var payload = seq.substring(marker + 2);
  if (payload.startsWith(';')) {
    payload = payload.substring(1);
  }
  if (payload.isEmpty) return const <Msg>[];

  final eq = payload.indexOf('=');
  if (eq == -1) {
    final name = _decodeHexAscii(payload);
    return [CapabilityMsg(name ?? payload)];
  }

  final nameHex = payload.substring(0, eq);
  final valueHex = payload.substring(eq + 1);
  final name = _decodeHexAscii(nameHex) ?? nameHex;
  final value = _decodeHexAscii(valueHex) ?? valueHex;
  return [CapabilityMsg('$name=$value')];
}

List<Msg> _decodeOsc(String seq) {
  if (seq.startsWith('10;')) {
    final rgb = _parseOscRgb(seq.substring(3));
    if (rgb != null) return [ForegroundColorMsg(rgb)];
    return const <Msg>[];
  }
  if (seq.startsWith('11;')) {
    final rgb = _parseOscRgb(seq.substring(3));
    if (rgb != null) return [BackgroundColorMsg(rgb)];
    return const <Msg>[];
  }
  if (seq.startsWith('12;')) {
    final rgb = _parseOscRgb(seq.substring(3));
    if (rgb != null) return [CursorColorMsg(rgb)];
    return const <Msg>[];
  }

  if (seq.startsWith('52;')) {
    final parts = seq.split(';');
    if (parts.length >= 3) {
      final selection = parts[1];
      final data = parts.sublist(2).join(';');
      final content = _decodeClipboardPayload(data);
      if (content != null) {
        return [
          ClipboardMsg(
            content: content,
            selection: selection == 'p' ? 1 : 0,
          ),
        ];
      }
    }
  }

  return const <Msg>[];
}

String? _decodeHexAscii(String text) {
  if (text.isEmpty || text.length.isOdd) return null;
  final bytes = <int>[];
  for (var i = 0; i < text.length; i += 2) {
    final part = text.substring(i, i + 2);
    final value = int.tryParse(part, radix: 16);
    if (value == null) return null;
    bytes.add(value);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

int? _parseOscRgb(String text) {
  final body = text.startsWith('rgb:') ? text.substring(4) : text;
  final parts = body.split('/');
  if (parts.length != 3) return null;
  final r = int.tryParse(parts[0], radix: 16);
  final g = int.tryParse(parts[1], radix: 16);
  final b = int.tryParse(parts[2], radix: 16);
  if (r == null || g == null || b == null) return null;
  final rr = parts[0].length > 2 ? (r >> (4 * (parts[0].length - 2))) : r;
  final gg = parts[1].length > 2 ? (g >> (4 * (parts[1].length - 2))) : g;
  final bb = parts[2].length > 2 ? (b >> (4 * (parts[2].length - 2))) : b;
  return ((rr & 0xff) << 16) | ((gg & 0xff) << 8) | (bb & 0xff);
}

String? _decodeClipboardPayload(String data) {
  if (data == '?') return null;
  try {
    final decoded = base64Decode(data);
    return utf8.decode(decoded, allowMalformed: true);
  } catch (_) {
    return null;
  }
}

Set<KeyMod> _mouseModifiersFromCb(int cb) {
  final mods = <KeyMod>{};
  if ((cb & 4) != 0) mods.add(KeyMod.shift);
  if ((cb & 8) != 0) mods.add(KeyMod.alt);
  if ((cb & 16) != 0) mods.add(KeyMod.ctrl);
  return mods;
}

MouseButton _mouseButtonFromCb(int cb) {
  final value = cb & 0x3;
  if ((cb & 64) != 0) {
    return switch (value) {
      0 => MouseButton.wheelUp,
      1 => MouseButton.wheelDown,
      _ => MouseButton.none,
    };
  }
  return switch (value) {
    0 => MouseButton.left,
    1 => MouseButton.middle,
    2 => MouseButton.right,
    _ => MouseButton.none,
  };
}
