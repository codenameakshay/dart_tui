// Run: fvm dart run example/textinputs.dart
// Multi-field form: name, email, password. Tab/shift+tab moves focus. Enter submits.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(TextInputsModel());
}

final class TextInputsModel extends TeaModel {
  TextInputsModel({
    TextInputModel? name,
    TextInputModel? email,
    TextInputModel? password,
    this.focusIndex = 0,
    this.submitted = false,
  })  : name = name ??
            TextInputModel(
              label: 'Name    :',
              placeholder: 'Jane Doe',
              focused: true,
            ),
        email = email ??
            TextInputModel(
              label: 'Email   :',
              placeholder: 'jane@example.com',
              focused: false,
            ),
        password = password ??
            TextInputModel(
              label: 'Password:',
              placeholder: 'super secret',
              echoMode: EchoMode.password,
              focused: false,
            );

  final TextInputModel name;
  final TextInputModel email;
  final TextInputModel password;
  final int focusIndex;
  final bool submitted;

  List<TextInputModel> get _fields => [name, email, password];

  TextInputsModel _withFields(List<TextInputModel> fields,
          {int? focus, bool? sub}) =>
      TextInputsModel(
        name: fields[0],
        email: fields[1],
        password: fields[2],
        focusIndex: focus ?? focusIndex,
        submitted: sub ?? submitted,
      );

  TextInputsModel _moveFocus(int delta) {
    final next = (focusIndex + delta) % 3;
    final fields = List<TextInputModel>.from(_fields);
    for (var i = 0; i < fields.length; i++) {
      fields[i] = fields[i].copyWith(focused: i == next);
    }
    return _withFields(fields, focus: next);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'ctrl+c':
        return (this, () => quit());
      case 'tab':
        return (_moveFocus(1), null);
      case 'shift+tab':
        return (_moveFocus(-1), null);
      case 'enter':
        if (focusIndex < 2) {
          return (_moveFocus(1), null);
        }
        return (_withFields(_fields, sub: true), null);
      default:
        final fields = List<TextInputModel>.from(_fields);
        final (updated, cmd) = fields[focusIndex].update(msg);
        fields[focusIndex] = updated as TextInputModel;
        return (_withFields(fields), cmd);
    }
  }

  @override
  View view() {
    if (submitted) {
      final b = StringBuffer('Form submitted!\n\n');
      b.writeln('  Name    : ${name.value}');
      b.writeln('  Email   : ${email.value}');
      b.writeln('  Password: ${'•' * password.value.length}');
      b.writeln('\nPress ctrl+c to quit.');
      return newView(b.toString());
    }
    final b =
        StringBuffer('Fill in the form (tab/shift+tab to switch fields):\n\n');
    for (var i = 0; i < _fields.length; i++) {
      final f = _fields[i];
      final cursor = i == focusIndex ? '> ' : '  ';
      b.writeln('$cursor${f.view().content}');
    }
    b.writeln('\nPress enter/tab to advance, ctrl+c to quit.');
    return newView(b.toString());
  }
}
