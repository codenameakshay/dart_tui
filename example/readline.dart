// Readline / emacs editing keys in a TextInputModel.
//   fvm dart run example/readline.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(ReadlineDemo());
}

final class ReadlineDemo extends TeaModel {
  ReadlineDemo({TextInputModel? input})
      : input = input ??
            TextInputModel(
              label: '>',
              value: 'the quick brown fox',
              cursorPos: 19,
            );

  final TextInputModel input;

  @override
  (Model, Cmd?) update(Msg msg) {
    // Esc / Ctrl+C quit (Esc is a no-op inside the input itself).
    if (msg is KeyMsg && (msg.key == 'esc' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    final (next, cmd) = input.update(msg);
    return (ReadlineDemo(input: next as TextInputModel), cmd);
  }

  @override
  View view() {
    const mauve = Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true);
    const dim = Style(foregroundRgb: RgbColor(108, 112, 134));
    const key = Style(foregroundRgb: RgbColor(137, 180, 250));

    String row(String k, String desc) =>
        '  ${key.render(k.padRight(18))}${dim.render(desc)}';

    final b = StringBuffer()
      ..writeln(mauve.render('Readline editing keys'))
      ..writeln()
      ..writeln(input.view().content)
      ..writeln()
      ..writeln(row('ctrl+a / ctrl+e', 'start / end of line'))
      ..writeln(row('ctrl+b / ctrl+f', 'char left / right'))
      ..writeln(row('alt+← / alt+→', 'word left / right'))
      ..writeln(row('ctrl+w / alt+⌫', 'delete previous word'))
      ..writeln()
      ..write(dim.render('Esc or ctrl+c to quit'));
    return newView(b.toString());
  }
}
