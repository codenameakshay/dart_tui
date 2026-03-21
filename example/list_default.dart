// Run: fvm dart run example/list_default.dart
// Extended list with item count and enter-to-select. Press q to quit.

import 'package:dart_tui/dart_tui.dart';

const _foods = [
  'Pizza',
  'Sushi',
  'Tacos',
  'Ramen',
  'Curry',
  'Pho',
  'Paella',
  'Burger',
  'Pad Thai',
  'Biryani',
];

Future<void> main() async {
  await Program().run(ListDefaultModel());
}

final class ListDefaultModel extends TeaModel {
  ListDefaultModel({
    SelectListModel? list,
    this.chosen = '',
  }) : list = list ??
            SelectListModel(
              title: 'Favourite food?',
              items: _foods,
            );

  final SelectListModel list;
  final String chosen;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case 'enter':
          return (
            ListDefaultModel(list: list, chosen: _foods[list.cursor]),
            null,
          );
      }
      final (updated, cmd) = list.update(msg);
      return (
        ListDefaultModel(list: updated as SelectListModel, chosen: chosen),
        cmd
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.write(list.view().content);
    b.writeln(
        'Items: ${_foods.length}  |  Cursor: ${list.cursor + 1}/${_foods.length}');
    if (chosen.isNotEmpty) {
      b.writeln('\nYou chose: $chosen');
    }
    b.writeln('\nPress enter to select, q to quit.');
    return newView(b.toString());
  }
}
