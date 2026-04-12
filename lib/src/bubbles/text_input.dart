import 'package:characters/characters.dart';
import '../cmd.dart';
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

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const InputStyles defaults = InputStyles(
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
        return (copyWith(value: nextChars.join(), cursorPos: cursorPos - 1), null);

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

      case 'tab':
        final suggestion = _activeSuggestion;
        if (suggestion != null) {
          return (
            copyWith(value: suggestion, cursorPos: suggestion.characters.length),
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
        if (msg.key.length >= 1) {
          // In dart_tui, msg.key for runes is the actual string
          if (charLimit > 0 && chars.length >= charLimit) return (this, null);
          final nextChars = List<String>.from(chars)..insert(cursorPos, msg.key);
          return (copyWith(value: nextChars.join(), cursorPos: cursorPos + 1), null);
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
        ? styles.suggestion.render(suggestion.characters.skip(chars.length).join())
        : '';

    final labelStyle = focused ? styles.focusedLabel : styles.label;
    final prefix = label.isEmpty ? '' : '${labelStyle.render(label)} ';
    
    final view = newView('$prefix${styles.text.render(displayValue)}$suggestionSuffix');
    
    if (focused) {
      // Calculate cursor position in cells, not characters
      final prefixWidth = _estimateWidth(label.isEmpty ? '' : '$label ');
      final textBeforeCursor = chars.sublist(0, cursorPos).join();
      final cursorX = prefixWidth + _estimateWidth(textBeforeCursor);
      view.cursor = Cursor(x: cursorX, y: 0, shape: CursorShape.bar);
    }
    
    return view;
  }

  static int _estimateWidth(String s) {
    var width = 0;
    for (final char in s.characters) {
      final code = char.runes.first;
      if (code >= 0x1100 &&
          (code <= 0x11ff ||
              (code >= 0x2e80 && code <= 0x9fff) ||
              (code >= 0xac00 && code <= 0xd7af) ||
              (code >= 0xf900 && code <= 0xfaff) ||
              (code >= 0xfe30 && code <= 0xfe4f) ||
              (code >= 0xff00 && code <= 0xff60) ||
              (code >= 0x1f300 && code <= 0x1f9ff))) {
        width += 2;
      } else {
        width += 1;
      }
    }
    return width;
  }
}
