// Run: fvm dart run example/autocomplete.dart
// Text input with color name autocomplete. Tab to accept suggestion, ctrl+c to quit.

import 'package:dart_tui/dart_tui.dart';

const _colors = [
  'red',
  'orange',
  'yellow',
  'green',
  'blue',
  'indigo',
  'violet',
  'pink',
  'purple',
  'cyan',
  'magenta',
  'teal',
  'black',
  'white',
];

Future<void> main() async {
  await Program().run(AutocompleteModel());
}

final class AutocompleteModel extends TeaModel {
  AutocompleteModel({TextInputModel? input})
      : input = input ??
            TextInputModel(
              label: 'Color:',
              placeholder: 'type a color name...',
              suggestions: _colors,
            );

  final TextInputModel input;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'ctrl+c') {
        return (this, () => quit());
      }
      final (updated, cmd) = input.update(msg);
      return (AutocompleteModel(input: updated as TextInputModel), cmd);
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer('Autocomplete demo\n\n');
    b.writeln('  ${input.view().content}');
    b.writeln();
    b.writeln('Available: ${_colors.join(', ')}');
    b.writeln('\nPress tab to complete, ctrl+c to quit.');
    return newView(b.toString());
  }
}
