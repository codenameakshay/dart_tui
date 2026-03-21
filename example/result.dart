// Run: fvm dart run example/result.dart
// OutcomeModel: select an item and the chosen value is returned to the caller.

import 'package:dart_tui/dart_tui.dart';

const _fruits = [
  'Apple',
  'Banana',
  'Cherry',
  'Date',
  'Elderberry',
  'Fig',
  'Grape',
];

Future<void> main() async {
  final result = await Program().runForResult<String>(ResultModel());
  if (result != null) {
    print('You selected: $result');
  } else {
    print('No selection made.');
  }
}

final class ResultModel extends OutcomeModel<String> {
  ResultModel({
    SelectListModel? list,
    this.outcome,
  }) : list = list ??
            SelectListModel(
              title: 'Pick a fruit:',
              items: _fruits,
            );

  final SelectListModel list;

  @override
  final String? outcome;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (ResultModel(list: list, outcome: null), () => quit());
        case 'enter':
          final chosen = _fruits[list.cursor];
          return (ResultModel(list: list, outcome: chosen), null);
      }
      final (updated, cmd) = list.update(msg);
      return (
        ResultModel(list: updated as SelectListModel, outcome: outcome),
        cmd
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.write(list.view().content);
    b.writeln('\nPress enter to select, q to cancel.');
    return newView(b.toString());
  }
}
