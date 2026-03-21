import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Single-line text field (keys: printable runes, backspace, enter).
final class TextInputModel extends TeaModel {
  TextInputModel({
    this.value = '',
    this.placeholder = '',
    this.label = '',
  });

  final String value;
  final String placeholder;
  final String label;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'backspace':
        if (value.isEmpty) return (this, null);
        return (
          TextInputModel(
            value: value.substring(0, value.length - 1),
            placeholder: placeholder,
            label: label,
          ),
          null,
        );
      case 'enter':
      case 'esc':
        return (this, null);
      default:
        if (msg.key.length == 1) {
          return (
            TextInputModel(
              value: value + msg.key,
              placeholder: placeholder,
              label: label,
            ),
            null,
          );
        }
        return (this, null);
    }
  }

  @override
  View view() {
    final display = value.isEmpty ? placeholder : value;
    return newView(label.isEmpty ? display : '$label $display');
  }
}
