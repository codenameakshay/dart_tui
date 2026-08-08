import 'package:characters/characters.dart';

import 'grapheme_width.dart';

const _escape = '\x1b';
const _osc8Close = '\x1b]8;;\x1b\\';

/// A printable grapheme, line break, or zero-width terminal control sequence.
final class AnsiToken {
  const AnsiToken(this.value, this.width, {this.isControl = false});

  final String value;
  final int width;
  final bool isControl;

  bool get isNewline => value == '\n';
  bool get isSpace => !isControl && value == ' ';
}

/// Splits terminal text without breaking graphemes or escape sequences.
List<AnsiToken> tokenizeAnsi(String input) {
  final tokens = <AnsiToken>[];
  var index = 0;
  while (index < input.length) {
    if (input[index] == _escape) {
      final end = _escapeSequenceEnd(input, index);
      if (end != null) {
        tokens.add(AnsiToken(input.substring(index, end), 0, isControl: true));
        index = end;
        continue;
      }
    }

    final grapheme = input.substring(index).characters.first;
    tokens.add(AnsiToken(grapheme, graphemeWidth(grapheme)));
    index += grapheme.length;
  }
  return tokens;
}

/// Removes terminal control sequences while preserving printable Unicode.
String stripAnsiSequences(String input) {
  if (!input.contains(_escape)) return input;
  return tokenizeAnsi(input)
      .where((token) => !token.isControl)
      .map((token) => token.value)
      .join();
}

/// Closes active SGR and OSC 8 state at newlines and reopens it afterwards.
///
/// Active state is also closed at the end so callers cannot leak it into the
/// rest of a terminal frame.
String balanceAnsiState(String input) {
  if (!input.contains(_escape)) return input;
  final state = AnsiStateTracker();
  final output = StringBuffer();
  for (final token in tokenizeAnsi(input)) {
    if (token.isNewline) {
      output
        ..write(state.closeSequence)
        ..write('\n')
        ..write(state.openSequence);
      continue;
    }
    output.write(token.value);
    if (token.isControl) state.accept(token.value);
  }
  output.write(state.closeSequence);
  return output.toString();
}

/// Tracks the terminal styling needed to safely cross a layout boundary.
final class AnsiStateTracker {
  final List<String> _sgr = [];
  String? _hyperlink;

  void accept(String sequence) {
    if (_isSgr(sequence)) {
      final parameters = sequence.substring(2, sequence.length - 1);
      final parts = parameters.isEmpty ? const ['0'] : parameters.split(';');
      final lastReset = parts.lastIndexWhere((part) => part == '0');
      if (lastReset >= 0) {
        _sgr.clear();
        if (lastReset < parts.length - 1) _sgr.add(sequence);
      } else {
        _sgr.add(sequence);
      }
      return;
    }

    final osc = _oscPayload(sequence);
    if (osc == null || !osc.startsWith('8;')) return;
    final separator = osc.indexOf(';', 2);
    if (separator < 0) return;
    final uri = osc.substring(separator + 1);
    _hyperlink = uri.isEmpty ? null : sequence;
  }

  String get closeSequence =>
      '${_sgr.isEmpty ? '' : '\x1b[0m'}${_hyperlink == null ? '' : _osc8Close}';

  String get sgrOpenSequence => _sgr.join();

  String get hyperlinkOpenSequence => _hyperlink ?? '';

  String get openSequence => '$hyperlinkOpenSequence$sgrOpenSequence';
}

bool _isSgr(String sequence) =>
    sequence.startsWith('\x1b[') && sequence.endsWith('m');

String? _oscPayload(String sequence) {
  if (!sequence.startsWith('\x1b]')) return null;
  if (sequence.endsWith('\x07')) {
    return sequence.substring(2, sequence.length - 1);
  }
  if (sequence.endsWith('\x1b\\')) {
    return sequence.substring(2, sequence.length - 2);
  }
  return null;
}

int? _escapeSequenceEnd(String input, int start) {
  if (start + 1 >= input.length) return null;
  final introducer = input.codeUnitAt(start + 1);
  if (introducer == 0x5b) {
    for (var index = start + 2; index < input.length; index++) {
      final code = input.codeUnitAt(index);
      if (code >= 0x40 && code <= 0x7e) return index + 1;
    }
    return null;
  }
  if (introducer == 0x5d || introducer == 0x50) {
    for (var index = start + 2; index < input.length; index++) {
      if (input.codeUnitAt(index) == 0x07) return index + 1;
      if (input.codeUnitAt(index) == 0x1b &&
          index + 1 < input.length &&
          input.codeUnitAt(index + 1) == 0x5c) {
        return index + 2;
      }
    }
    return null;
  }
  if (introducer == 0x4f && start + 2 < input.length) return start + 3;
  return start + 2;
}
