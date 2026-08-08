import 'package:characters/characters.dart';
import '../cmd.dart';
import '../grapheme_width.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// How the text input renders its value.
enum EchoMode {
  /// Normal: display the value as typed.
  normal,

  /// Password: display bullet characters (•) instead of the value.
  password,

  /// None: display nothing (value is tracked but not shown).
  none,
}

/// Style configuration for [TextInputModel] and [TextAreaModel].
final class InputStyles {
  const InputStyles({
    this.label = const Style(),
    this.focusedLabel = const Style(),
    this.text = const Style(),
    this.placeholder = const Style(),
    this.suggestion = const Style(),
  });

  factory InputStyles.forDarkBackground(bool isDark) => isDark ? dark : light;

  factory InputStyles.forBackground(int rgb) =>
      InputStyles.forDarkBackground(isDarkRgb(rgb));

  /// Applied to the label when unfocused.
  final Style label;

  /// Applied to the label when the field is focused.
  final Style focusedLabel;

  /// Applied to the typed text.
  final Style text;

  /// Applied to the placeholder when value is empty and unfocused.
  final Style placeholder;

  /// Applied to the dimmed autocomplete suggestion suffix.
  final Style suggestion;

  static const InputStyles dark = InputStyles(
    label: Style(
      foregroundRgb: RgbColor(166, 173, 200), // Subtext0
    ),
    focusedLabel: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    text: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
    ),
    placeholder: Style(
      foregroundRgb: RgbColor(108, 112, 134), // Overlay0
      isDim: true,
      isItalic: true,
    ),
    suggestion: Style(
      foregroundRgb: RgbColor(108, 112, 134), // Overlay0
      isDim: true,
    ),
  );

  static const InputStyles light = InputStyles(
    label: Style(foregroundRgb: RgbColor(108, 111, 133)),
    focusedLabel: Style(
      foregroundRgb: RgbColor(136, 57, 239),
      isBold: true,
    ),
    text: Style(foregroundRgb: RgbColor(76, 79, 105)),
    placeholder: Style(
      foregroundRgb: RgbColor(108, 111, 133),
      isItalic: true,
    ),
    suggestion: Style(foregroundRgb: RgbColor(108, 111, 133)),
  );

  /// Defaults remain optimized for dark terminal backgrounds.
  static const InputStyles defaults = dark;
}

/// Single-line text field with full Bubbletea-compatible feature set.
final class TextInputModel extends TeaModel {
  TextInputModel({
    this.value = '',
    this.cursorPos = 0,
    this.placeholder = '',
    this.label = '',
    this.echoMode = EchoMode.normal,
    this.charLimit = 0,
    this.focused = true,
    this.validate,
    this.suggestions = const [],
    this.styles = InputStyles.defaults,
  });

  final String value;

  /// Cursor position within [value] (0 = before first char, value.length = after last).
  final int cursorPos;

  final String placeholder;
  final String label;
  final EchoMode echoMode;

  /// Maximum number of characters. 0 = unlimited.
  final int charLimit;

  final bool focused;

  /// Optional validation called on Enter. Return `false` to reject input and
  /// emit [ValidationFailedMsg].
  final bool Function(String value)? validate;

  /// Suggested completions. The first entry that starts with [value] is shown
  /// dimmed after the cursor; Tab accepts it.
  final List<String> suggestions;

  final InputStyles styles;

  TextInputModel copyWith({
    String? value,
    int? cursorPos,
    String? placeholder,
    String? label,
    EchoMode? echoMode,
    int? charLimit,
    bool? focused,
    bool Function(String)? validate,
    List<String>? suggestions,
    InputStyles? styles,
  }) =>
      TextInputModel(
        value: value ?? this.value,
        cursorPos: cursorPos ?? this.cursorPos,
        placeholder: placeholder ?? this.placeholder,
        label: label ?? this.label,
        echoMode: echoMode ?? this.echoMode,
        charLimit: charLimit ?? this.charLimit,
        focused: focused ?? this.focused,
        validate: validate ?? this.validate,
        suggestions: suggestions ?? this.suggestions,
        styles: styles ?? this.styles,
      );

  String? get _activeSuggestion {
    if (suggestions.isEmpty || value.isEmpty) return null;
    for (final s in suggestions) {
      if (s.startsWith(value) && s != value) return s;
    }
    return null;
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final chars = value.characters.toList();
    switch (msg.key) {
      case 'backspace':
        if (value.isEmpty || cursorPos == 0) return (this, null);
        final nextChars = List<String>.from(chars)..removeAt(cursorPos - 1);
        return (
          copyWith(value: nextChars.join(), cursorPos: cursorPos - 1),
          null
        );

      case 'delete':
        if (cursorPos >= chars.length) return (this, null);
        final nextChars = List<String>.from(chars)..removeAt(cursorPos);
        return (copyWith(value: nextChars.join()), null);

      case 'left':
        if (cursorPos == 0) return (this, null);
        return (copyWith(cursorPos: cursorPos - 1), null);

      case 'right':
        if (cursorPos >= chars.length) return (this, null);
        return (copyWith(cursorPos: cursorPos + 1), null);

      case 'home':
        return (copyWith(cursorPos: 0), null);

      case 'end':
        return (copyWith(cursorPos: chars.length), null);

      // ── Readline / emacs bindings ──────────────────────────────────────────
      case 'ctrl+a':
        return (copyWith(cursorPos: 0), null);
      case 'ctrl+e':
        return (copyWith(cursorPos: chars.length), null);
      case 'ctrl+b':
        if (cursorPos == 0) return (this, null);
        return (copyWith(cursorPos: cursorPos - 1), null);
      case 'ctrl+f':
        if (cursorPos >= chars.length) return (this, null);
        return (copyWith(cursorPos: cursorPos + 1), null);
      case 'alt+left': // Alt+B / ⌥←
        return (copyWith(cursorPos: _wordStartBefore(chars, cursorPos)), null);
      case 'alt+right': // Alt+F / ⌥→
        return (copyWith(cursorPos: _wordEndAfter(chars, cursorPos)), null);
      case 'ctrl+w':
      case 'alt+backspace':
        final start = _wordStartBefore(chars, cursorPos);
        if (start == cursorPos) return (this, null);
        final next = [...chars.sublist(0, start), ...chars.sublist(cursorPos)];
        return (copyWith(value: next.join(), cursorPos: start), null);

      case 'tab':
        final suggestion = _activeSuggestion;
        if (suggestion != null) {
          return (
            copyWith(
                value: suggestion, cursorPos: suggestion.characters.length),
            null
          );
        }
        return (this, null);

      case 'enter':
        if (validate != null && !validate!(value)) {
          return (this, () => ValidationFailedMsg(value));
        }
        return (this, null);

      case 'esc':
        return (this, null);

      default:
        if (!focused) return (this, null);
        // Insert the actual rune text — msg.key would be 'space' for the space
        // key, 'f1' for F-keys, etc. Only unmodified printable runes are typed.
        final ke = msg.keyEvent;
        if (ke.code == KeyCode.rune &&
            ke.text.isNotEmpty &&
            ke.modifiers.isEmpty) {
          final inserted = ke.text.characters.toList();
          if (charLimit > 0 && chars.length + inserted.length > charLimit) {
            return (this, null);
          }
          final nextChars = List<String>.from(chars)
            ..insertAll(cursorPos, inserted);
          return (
            copyWith(
              value: nextChars.join(),
              cursorPos: cursorPos + inserted.length,
            ),
            null
          );
        }
        return (this, null);
    }
  }

  @override
  View view() {
    final chars = value.characters.toList();
    if (!focused && value.isEmpty) {
      final display = label.isEmpty ? placeholder : '$label $placeholder';
      return newView(styles.placeholder.render(display));
    }

    String displayValue;
    switch (echoMode) {
      case EchoMode.normal:
        displayValue = value;
      case EchoMode.password:
        displayValue = '•' * chars.length;
      case EchoMode.none:
        displayValue = '';
    }

    final suggestion = _activeSuggestion;
    final suggestionSuffix = (echoMode == EchoMode.normal && suggestion != null)
        ? styles.suggestion
            .render(suggestion.characters.skip(chars.length).join())
        : '';

    final labelStyle = focused ? styles.focusedLabel : styles.label;
    final prefix = label.isEmpty ? '' : '${labelStyle.render(label)} ';

    final view =
        newView('$prefix${styles.text.render(displayValue)}$suggestionSuffix');

    if (focused) {
      // Calculate cursor position in cells, not characters
      final prefixWidth = textWidth(label.isEmpty ? '' : '$label ');
      final textBeforeCursor = chars.sublist(0, cursorPos).join();
      final cursorX = prefixWidth + textWidth(textBeforeCursor);
      view.cursor = Cursor(x: cursorX, y: 0, shape: CursorShape.bar);
    }

    return view;
  }

  /// Index of the start of the word before [pos] (skips trailing spaces, then
  /// the run of non-space characters). Used by word-motion / word-delete keys.
  static int _wordStartBefore(List<String> chars, int pos) {
    var i = pos;
    while (i > 0 && chars[i - 1] == ' ') {
      i--;
    }
    while (i > 0 && chars[i - 1] != ' ') {
      i--;
    }
    return i;
  }

  /// Index just after the word at/after [pos] (skips leading spaces, then the
  /// run of non-space characters).
  static int _wordEndAfter(List<String> chars, int pos) {
    var i = pos;
    while (i < chars.length && chars[i] == ' ') {
      i++;
    }
    while (i < chars.length && chars[i] != ' ') {
      i++;
    }
    return i;
  }
}
