// Run: fvm dart run example/textinput.dart
// Single text input with placeholder and char limit. Enter to submit, q to quit.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(TextInputExampleModel());
}

final class TextInputExampleModel extends TeaModel {
  TextInputExampleModel({
    TextInputModel? input,
    this.submitted = false,
    this.result = '',
  }) : input = input ??
            TextInputModel(
              placeholder: 'What is your name?',
              charLimit: 50,
            );

  final TextInputModel input;
  final bool submitted;
  final String result;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'ctrl+c':
          return (this, () => quit());
        case 'q':
          if (!input.focused || input.value.isEmpty) {
            return (this, () => quit());
          }
        case 'enter':
          if (input.value.isNotEmpty) {
            return (
              TextInputExampleModel(
                input: input,
                submitted: true,
                result: input.value,
              ),
              null,
            );
          }
      }
      final (newInput, cmd) = input.update(msg);
      return (
        TextInputExampleModel(
          input: newInput as TextInputModel,
          submitted: submitted,
          result: result,
        ),
        cmd,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    if (submitted) {
      return newView('You typed: $result\n\nPress ctrl+c to quit.');
    }
    final b = StringBuffer();
    b.writeln('Enter your name:');
    b.writeln();
    b.writeln('  > ${input.view().content}');
    b.writeln();
    b.writeln('Press enter to submit, ctrl+c to quit.');
    return newView(b.toString());
  }
}
