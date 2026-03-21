import 'package:dart_console/dart_console.dart' as dc;

import 'key_buffer_parser.dart';
import 'key_util.dart';
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

      final dc.Key? key = parseKeyFromBuffer(_buffer);
      if (key != null) {
        out.add(KeyPressMsg(toTeaKey(key)));
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
