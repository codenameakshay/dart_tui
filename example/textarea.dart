// Run: fvm dart run example/textarea.dart
// Multi-line text editor. ctrl+c to quit.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(TextAreaExampleModel());
}

final class TextAreaExampleModel extends TeaModel {
  TextAreaExampleModel({TextAreaModel? area})
      : area = area ??
            TextAreaModel(
              placeholder: 'Start typing...',
              width: 60,
              maxHeight: 10,
            );

  final TextAreaModel area;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'ctrl+c') {
        return (this, () => quit());
      }
      final (updated, cmd) = area.update(msg);
      return (TextAreaExampleModel(area: updated as TextAreaModel), cmd);
    }
    return (this, null);
  }

  @override
  View view() {
    final lines = area.lines.length;
    final b = StringBuffer('Multi-line editor (ctrl+c to quit):\n\n');
    b.writeln(area.view().content);
    b.writeln('\n─── $lines line${lines == 1 ? '' : 's'} ───');
    return newView(b.toString());
  }
}
