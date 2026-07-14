// Ported from charmbracelet/bubbletea examples/pipe
import 'dart:io';
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  // If stdin is piped, read all input first
  if (!stdin.hasTerminal) {
    final content =
        await stdin.transform(const SystemEncoding().decoder).join();
    print('Received piped input:\n\n$content');
    return;
  }

  await Program().run(PipeModel());
}

final class PipeModel extends TeaModel {
  PipeModel({TextInputModel? input, this.submitted = false})
      : input = input ??
            TextInputModel(
              placeholder: 'Or type here interactively...',
              label: 'Input: ',
              charLimit: 256,
            );

  final TextInputModel input;
  final bool submitted;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'ctrl+c':
        case 'esc':
          return (this, () => quit());
        case 'enter':
          return (PipeModel(input: input, submitted: true), null);
      }
    }
    final (next, cmd) = input.update(msg);
    return (
      PipeModel(input: next as TextInputModel, submitted: submitted),
      cmd,
    );
  }

  @override
  View view() {
    if (submitted) {
      return newView('You entered: ${input.value}\n\nPress esc to quit.');
    }
    return newView(
      'Pipe example\n\n'
      'Run with: echo "hello" | fvm dart run example/pipe.dart\n\n'
      '${input.view().content}\n\n'
      'enter: submit  •  esc: quit',
    );
  }
}
