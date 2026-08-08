import 'msg.dart';
import 'view.dart';

int keyboardEnhancementFlags(KeyboardEnhancements enhancements) {
  var flags = kittyDisambiguateEscapeCodes;
  if (enhancements.reportEventTypes) flags |= kittyReportEventTypes;
  if (enhancements.reportAlternateKeys) flags |= kittyReportAlternateKeys;
  if (enhancements.reportAllKeysAsEscapeCodes) {
    flags |= kittyReportAllKeysAsEscapeCodes;
  }
  if (enhancements.reportAssociatedText) flags |= kittyReportAssociatedText;
  return flags;
}

/// Decodes Kitty CSI keyboard sequences.
///
/// Returns `null` when [sequence] is not a keyboard sequence, an empty list
/// when it is a complete but malformed keyboard sequence, and one message for
/// a valid capability report or key event.
List<Msg>? decodeKittyKeyboard(String sequence) {
  if (sequence.startsWith('?') && sequence.endsWith('u')) {
    final body = sequence.substring(1, sequence.length - 1);
    final flags = body.isEmpty ? 0 : int.tryParse(body);
    if (flags == null || flags < 0) return const <Msg>[];
    return <Msg>[KeyboardEnhancementsMsg(flags)];
  }

  if (sequence.endsWith('u')) {
    final body = sequence.substring(0, sequence.length - 1);
    return _decodeCanonicalKey(body);
  }

  final finalByte = sequence.isEmpty ? '' : sequence[sequence.length - 1];
  if (finalByte == 'Z') {
    final body = sequence.substring(0, sequence.length - 1);
    if (body.isNotEmpty && body != '1') return const <Msg>[];
    return <Msg>[
      KeyPressMsg(const TeaKey(
        code: KeyCode.tab,
        modifiers: <KeyMod>{KeyMod.shift},
      )),
    ];
  }
  final functional = _functionalKeyForFinal(finalByte);
  if (functional != null) {
    return _decodeFunctionalKey(
      sequence.substring(0, sequence.length - 1),
      functional,
    );
  }

  if (finalByte == '~') {
    return _decodeTildeKey(sequence.substring(0, sequence.length - 1));
  }

  return null;
}

List<Msg> _decodeCanonicalKey(String body) {
  final fields = body.split(';');
  if (fields.isEmpty || fields.length > 3 || fields.first.isEmpty) {
    return const <Msg>[];
  }

  final keyCodes = fields[0].split(':');
  if (keyCodes.length > 3) return const <Msg>[];
  final codePoint = int.tryParse(keyCodes[0]);
  if (codePoint == null || !_isValidCodePoint(codePoint)) {
    return const <Msg>[];
  }

  int? shiftedCode;
  int? baseCode;
  if (keyCodes.length > 1 && keyCodes[1].isNotEmpty) {
    shiftedCode = int.tryParse(keyCodes[1]);
    if (shiftedCode == null || !_isPrintableCodePoint(shiftedCode)) {
      return const <Msg>[];
    }
  }
  if (keyCodes.length > 2 && keyCodes[2].isNotEmpty) {
    baseCode = int.tryParse(keyCodes[2]);
    if (baseCode == null || !_isPrintableCodePoint(baseCode)) {
      return const <Msg>[];
    }
  }

  final modifier = _parseModifier(fields.length > 1 ? fields[1] : '');
  if (modifier == null) return const <Msg>[];

  var associatedText = '';
  if (fields.length > 2 && fields[2].isNotEmpty) {
    final buffer = StringBuffer();
    for (final part in fields[2].split(':')) {
      final value = int.tryParse(part);
      if (value == null || !_isPrintableCodePoint(value)) {
        return const <Msg>[];
      }
      buffer.writeCharCode(value);
    }
    associatedText = buffer.toString();
  }

  return <Msg>[
    _keyMessage(
      codePoint: codePoint,
      modifier: modifier,
      shiftedCode: shiftedCode,
      baseCode: baseCode,
      associatedText: associatedText,
    ),
  ];
}

List<Msg> _decodeFunctionalKey(String body, KeyCode code) {
  final fields = body.isEmpty ? const <String>[] : body.split(';');
  if (fields.length > 2) return const <Msg>[];
  if (fields.isNotEmpty && fields.first.isNotEmpty && fields.first != '1') {
    return const <Msg>[];
  }
  final modifier = _parseModifier(fields.length > 1 ? fields[1] : '');
  if (modifier == null) return const <Msg>[];
  return <Msg>[
    _eventMessage(
        TeaKey(
            code: code,
            modifiers: modifier.modifiers,
            isRepeat: modifier.eventType == 2),
        modifier.eventType)
  ];
}

List<Msg> _decodeTildeKey(String body) {
  final fields = body.split(';');
  if (fields.isEmpty || fields.length > 3) return const <Msg>[];
  final number = int.tryParse(fields[0]);
  if (number == null) return const <Msg>[];

  if (number == 27 && fields.length == 3) {
    final codePoint = int.tryParse(fields[2]);
    final modifier = _parseModifier(fields[1]);
    if (codePoint == null ||
        !_isValidCodePoint(codePoint) ||
        modifier == null) {
      return const <Msg>[];
    }
    return <Msg>[
      _keyMessage(codePoint: codePoint, modifier: modifier),
    ];
  }

  final code = _tildeKeyCodes[number];
  if (code == null) return const <Msg>[];
  final modifier = _parseModifier(fields.length > 1 ? fields[1] : '');
  if (modifier == null) return const <Msg>[];
  final key = TeaKey(
    code: code,
    modifiers: modifier.modifiers,
    isRepeat: modifier.eventType == 2,
  );
  return <Msg>[_eventMessage(key, modifier.eventType)];
}

Msg _keyMessage({
  required int codePoint,
  required _KittyModifier modifier,
  int? shiftedCode,
  int? baseCode,
  String associatedText = '',
}) {
  var code = _kittyKeyCode(codePoint);
  final modifiers = <KeyMod>{...modifier.modifiers};

  if (code == null && codePoint == 0) {
    if (associatedText.isNotEmpty) {
      code = KeyCode.rune;
    } else {
      code = KeyCode.space;
      modifiers.add(KeyMod.ctrl);
    }
  } else if (code == null && codePoint >= 1 && codePoint <= 26) {
    code = KeyCode.rune;
    modifiers.add(KeyMod.ctrl);
  } else if (code == null && codePoint >= 28 && codePoint <= 31) {
    code = KeyCode.rune;
    modifiers.add(KeyMod.ctrl);
  } else if (code == null && _isTextCodePoint(codePoint)) {
    code = KeyCode.rune;
  } else {
    code ??= KeyCode.extended;
  }

  var text = associatedText;
  final textModifiers = modifiers
      .where(
          (modifier) => modifier != KeyMod.shift && modifier != KeyMod.capsLock)
      .isEmpty;
  if (text.isEmpty && code == KeyCode.rune && textModifiers) {
    var textCodePoint = codePoint;
    if (shiftedCode != null && modifiers.contains(KeyMod.shift)) {
      textCodePoint = shiftedCode;
    }
    if (_isPrintableCodePoint(textCodePoint)) {
      text = String.fromCharCode(textCodePoint);
      final upper = modifiers.contains(KeyMod.shift) !=
          modifiers.contains(KeyMod.capsLock);
      if (upper && shiftedCode == null) text = text.toUpperCase();
    }
  }

  if (code == KeyCode.rune &&
      text.isEmpty &&
      codePoint >= 1 &&
      codePoint <= 26) {
    text = String.fromCharCode(codePoint + 0x60);
  } else if (code == KeyCode.rune &&
      text.isEmpty &&
      codePoint >= 28 &&
      codePoint <= 31) {
    text = String.fromCharCode(codePoint + 0x40);
  }

  final key = TeaKey(
    code: code,
    text: text,
    modifiers: modifiers,
    codePoint: codePoint,
    shiftedCode: shiftedCode,
    baseCode: baseCode,
    associatedText: associatedText,
    isRepeat: modifier.eventType == 2,
  );
  return _eventMessage(key, modifier.eventType);
}

Msg _eventMessage(TeaKey key, int eventType) =>
    eventType == 3 ? KeyReleaseMsg(key) : KeyPressMsg(key);

_KittyModifier? _parseModifier(String field) {
  if (field.isEmpty) return const _KittyModifier(<KeyMod>{}, 1);
  final parts = field.split(':');
  if (parts.length > 2) return null;
  final encoded = parts[0].isEmpty ? 1 : int.tryParse(parts[0]);
  final eventType =
      parts.length == 1 || parts[1].isEmpty ? 1 : int.tryParse(parts[1]);
  if (encoded == null ||
      encoded < 1 ||
      eventType == null ||
      eventType < 1 ||
      eventType > 3) {
    return null;
  }

  final bits = encoded - 1;
  final modifiers = <KeyMod>{};
  if ((bits & 1) != 0) modifiers.add(KeyMod.shift);
  if ((bits & 2) != 0) modifiers.add(KeyMod.alt);
  if ((bits & 4) != 0) modifiers.add(KeyMod.ctrl);
  if ((bits & 8) != 0) modifiers.add(KeyMod.superKey);
  if ((bits & 16) != 0) modifiers.add(KeyMod.hyper);
  if ((bits & 32) != 0) modifiers.add(KeyMod.meta);
  if ((bits & 64) != 0) modifiers.add(KeyMod.capsLock);
  if ((bits & 128) != 0) modifiers.add(KeyMod.numLock);
  return _KittyModifier(modifiers, eventType);
}

KeyCode? _functionalKeyForFinal(String finalByte) => switch (finalByte) {
      'A' => KeyCode.up,
      'B' => KeyCode.down,
      'C' => KeyCode.right,
      'D' => KeyCode.left,
      'H' => KeyCode.home,
      'F' => KeyCode.end,
      'P' => KeyCode.f1,
      'Q' => KeyCode.f2,
      'R' => KeyCode.f3,
      'S' => KeyCode.f4,
      _ => null,
    };

KeyCode? _kittyKeyCode(int codePoint) {
  final direct = _kittyDirectKeyCodes[codePoint];
  if (direct != null) return direct;
  if (codePoint >= 57364 && codePoint <= 57398) {
    return _kittyFunctionKeys[codePoint - 57364];
  }
  return null;
}

bool _isValidCodePoint(int value) =>
    value >= 0 && value <= 0x10ffff && !(value >= 0xd800 && value <= 0xdfff);

bool _isPrintableCodePoint(int value) =>
    _isValidCodePoint(value) &&
    value >= 0x20 &&
    value != 0x7f &&
    !(value >= 0x80 && value <= 0x9f);

bool _isTextCodePoint(int value) =>
    _isPrintableCodePoint(value) && !(value >= 0xe000 && value <= 0xf8ff);

final class _KittyModifier {
  const _KittyModifier(this.modifiers, this.eventType);

  final Set<KeyMod> modifiers;
  final int eventType;
}

const _kittyFunctionKeys = <KeyCode>[
  KeyCode.f1,
  KeyCode.f2,
  KeyCode.f3,
  KeyCode.f4,
  KeyCode.f5,
  KeyCode.f6,
  KeyCode.f7,
  KeyCode.f8,
  KeyCode.f9,
  KeyCode.f10,
  KeyCode.f11,
  KeyCode.f12,
  KeyCode.f13,
  KeyCode.f14,
  KeyCode.f15,
  KeyCode.f16,
  KeyCode.f17,
  KeyCode.f18,
  KeyCode.f19,
  KeyCode.f20,
  KeyCode.f21,
  KeyCode.f22,
  KeyCode.f23,
  KeyCode.f24,
  KeyCode.f25,
  KeyCode.f26,
  KeyCode.f27,
  KeyCode.f28,
  KeyCode.f29,
  KeyCode.f30,
  KeyCode.f31,
  KeyCode.f32,
  KeyCode.f33,
  KeyCode.f34,
  KeyCode.f35,
];

const _kittyDirectKeyCodes = <int, KeyCode>{
  8: KeyCode.backspace,
  9: KeyCode.tab,
  13: KeyCode.enter,
  27: KeyCode.escape,
  127: KeyCode.backspace,
  57344: KeyCode.escape,
  57345: KeyCode.enter,
  57346: KeyCode.tab,
  57347: KeyCode.backspace,
  57348: KeyCode.insert,
  57349: KeyCode.delete,
  57350: KeyCode.left,
  57351: KeyCode.right,
  57352: KeyCode.up,
  57353: KeyCode.down,
  57354: KeyCode.pageUp,
  57355: KeyCode.pageDown,
  57356: KeyCode.home,
  57357: KeyCode.end,
  57358: KeyCode.capsLock,
  57359: KeyCode.scrollLock,
  57360: KeyCode.numLock,
  57361: KeyCode.printScreen,
  57362: KeyCode.pause,
  57363: KeyCode.menu,
  57399: KeyCode.keypad0,
  57400: KeyCode.keypad1,
  57401: KeyCode.keypad2,
  57402: KeyCode.keypad3,
  57403: KeyCode.keypad4,
  57404: KeyCode.keypad5,
  57405: KeyCode.keypad6,
  57406: KeyCode.keypad7,
  57407: KeyCode.keypad8,
  57408: KeyCode.keypad9,
  57409: KeyCode.keypadDecimal,
  57410: KeyCode.keypadDivide,
  57411: KeyCode.keypadMultiply,
  57412: KeyCode.keypadMinus,
  57413: KeyCode.keypadPlus,
  57414: KeyCode.keypadEnter,
  57415: KeyCode.keypadEqual,
  57416: KeyCode.keypadSeparator,
  57417: KeyCode.keypadLeft,
  57418: KeyCode.keypadRight,
  57419: KeyCode.keypadUp,
  57420: KeyCode.keypadDown,
  57421: KeyCode.keypadPageUp,
  57422: KeyCode.keypadPageDown,
  57423: KeyCode.keypadHome,
  57424: KeyCode.keypadEnd,
  57425: KeyCode.keypadInsert,
  57426: KeyCode.keypadDelete,
  57427: KeyCode.keypadBegin,
  57428: KeyCode.mediaPlay,
  57429: KeyCode.mediaPause,
  57430: KeyCode.mediaPlayPause,
  57431: KeyCode.mediaReverse,
  57432: KeyCode.mediaStop,
  57433: KeyCode.mediaFastForward,
  57434: KeyCode.mediaRewind,
  57435: KeyCode.mediaNext,
  57436: KeyCode.mediaPrevious,
  57437: KeyCode.mediaRecord,
  57438: KeyCode.volumeDown,
  57439: KeyCode.volumeUp,
  57440: KeyCode.volumeMute,
  57441: KeyCode.leftShift,
  57442: KeyCode.leftControl,
  57443: KeyCode.leftAlt,
  57444: KeyCode.leftSuper,
  57445: KeyCode.leftHyper,
  57446: KeyCode.leftMeta,
  57447: KeyCode.rightShift,
  57448: KeyCode.rightControl,
  57449: KeyCode.rightAlt,
  57450: KeyCode.rightSuper,
  57451: KeyCode.rightHyper,
  57452: KeyCode.rightMeta,
  57453: KeyCode.isoLevel3Shift,
  57454: KeyCode.isoLevel5Shift,
};

const _tildeKeyCodes = <int, KeyCode>{
  1: KeyCode.home,
  2: KeyCode.insert,
  3: KeyCode.delete,
  4: KeyCode.end,
  5: KeyCode.pageUp,
  6: KeyCode.pageDown,
  7: KeyCode.home,
  8: KeyCode.end,
  11: KeyCode.f1,
  12: KeyCode.f2,
  13: KeyCode.f3,
  14: KeyCode.f4,
  15: KeyCode.f5,
  17: KeyCode.f6,
  18: KeyCode.f7,
  19: KeyCode.f8,
  20: KeyCode.f9,
  21: KeyCode.f10,
  23: KeyCode.f11,
  24: KeyCode.f12,
  25: KeyCode.f13,
  26: KeyCode.f14,
  28: KeyCode.f15,
  29: KeyCode.f16,
  31: KeyCode.f17,
  32: KeyCode.f18,
  33: KeyCode.f19,
  34: KeyCode.f20,
};
