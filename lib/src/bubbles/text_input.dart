import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// How the text input renders its value.
enum EchoMode {
  /// Normal: display the value as typed.
  normal,

  /// Password: display bullet characters (•) instead of the value.
  password,

  /// None: display nothing (value is tracked but not shown).
  none,
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
    switch (msg.key) {
      case 'backspace':
        if (value.isEmpty || cursorPos == 0) return (this, null);
        final newValue =
            value.substring(0, cursorPos - 1) + value.substring(cursorPos);
        return (copyWith(value: newValue, cursorPos: cursorPos - 1), null);

      case 'delete':
        if (cursorPos >= value.length) return (this, null);
        final newValue =
            value.substring(0, cursorPos) + value.substring(cursorPos + 1);
        return (copyWith(value: newValue), null);

      case 'left':
        if (cursorPos == 0) return (this, null);
        return (copyWith(cursorPos: cursorPos - 1), null);

      case 'right':
        if (cursorPos >= value.length) return (this, null);
        return (copyWith(cursorPos: cursorPos + 1), null);

      case 'home':
        return (copyWith(cursorPos: 0), null);

      case 'end':
        return (copyWith(cursorPos: value.length), null);

      case 'tab':
        final suggestion = _activeSuggestion;
        if (suggestion != null) {
          return (
            copyWith(value: suggestion, cursorPos: suggestion.length),
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
        if (msg.key.length == 1) {
          if (charLimit > 0 && value.length >= charLimit) return (this, null);
          final newValue = value.substring(0, cursorPos) +
              msg.key +
              value.substring(cursorPos);
          return (copyWith(value: newValue, cursorPos: cursorPos + 1), null);
        }
        return (this, null);
    }
  }

  @override
  View view() {
    if (!focused && value.isEmpty) {
      final display = label.isEmpty ? placeholder : '$label $placeholder';
      return newView('\x1b[2m$display\x1b[0m'); // dim placeholder
    }

    String displayValue;
    switch (echoMode) {
      case EchoMode.normal:
        displayValue = value;
      case EchoMode.password:
        displayValue = '•' * value.length;
      case EchoMode.none:
        displayValue = '';
    }

    final suggestion = _activeSuggestion;
    final suffix = (echoMode == EchoMode.normal && suggestion != null)
        ? '\x1b[2m${suggestion.substring(value.length)}\x1b[0m'
        : '';

    final prefix = label.isEmpty ? '' : '$label ';
    return newView('$prefix$displayValue$suffix');
  }
}
