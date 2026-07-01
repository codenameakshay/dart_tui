// ListModel runtime mutation API: add (a) and delete (d) items live.
//   fvm dart run example/list_mutation.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(MutationDemo());
}

final class MutationDemo extends TeaModel {
  MutationDemo({ListModel? list, this.counter = 3})
      : list = list ??
            ListModel(
              title: 'Tasks',
              items: const [
                ListItem(title: 'Task 1'),
                ListItem(title: 'Task 2'),
                ListItem(title: 'Task 3'),
              ],
              showStatusBar: true,
              showDescription: false,
            );

  final ListModel list;
  final int counter;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'a':
          final next = counter + 1;
          return (
            MutationDemo(
              list: list.appendItem(ListItem(title: 'Task $next')),
              counter: next,
            ),
            null,
          );
        case 'd':
          return (
            MutationDemo(
              list: list.removeItemAt(list.selectedIndex),
              counter: counter,
            ),
            null,
          );
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    // Delegate navigation (↑↓ / jk) to the list.
    final (next, cmd) = list.update(msg);
    return (MutationDemo(list: next as ListModel, counter: counter), cmd);
  }

  @override
  View view() {
    const dim = Style(foregroundRgb: RgbColor(108, 112, 134));
    final b = StringBuffer()
      ..writeln(list.view().content)
      ..writeln()
      ..write(dim.render('a add · d delete · ↑↓/jk move · q quit'));
    return newView(b.toString());
  }
}
