// Run: fvm dart run example/list_simple.dart
// Simple SelectListModel with programming languages. Up/down to navigate, q to quit.

import 'package:dart_tui/dart_tui.dart';

const _languages = [
  'Dart',
  'Go',
  'Rust',
  'TypeScript',
  'Python',
  'Kotlin',
  'Swift',
  'Elixir',
  'Haskell',
  'Zig',
];

Future<void> main() async {
  await Program().run(ListSimpleModel());
}

final class ListSimpleModel extends TeaModel {
  ListSimpleModel({SelectListModel? list})
      : list = list ??
            SelectListModel(
              title: 'Pick a programming language:',
              items: _languages,
            );

  final SelectListModel list;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
      final (updated, cmd) = list.update(msg);
      return (ListSimpleModel(list: updated as SelectListModel), cmd);
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.write(list.view().content);
    b.writeln('\nCurrent: ${_languages[list.cursor]}');
    b.writeln('Press q to quit.');
    return newView(b.toString());
  }
}
