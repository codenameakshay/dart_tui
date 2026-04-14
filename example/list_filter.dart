// Interactive list with fuzzy filtering — demonstrates ListModel.
// Run: fvm dart run example/list_filter.dart

import 'package:dart_tui/dart_tui.dart';

const _items = [
  ListItem(title: 'Apple', description: 'A crisp red fruit'),
  ListItem(title: 'Banana', description: 'A yellow tropical fruit'),
  ListItem(title: 'Cherry', description: 'A small stone fruit'),
  ListItem(title: 'Date', description: 'A sweet dried fruit'),
  ListItem(title: 'Elderberry', description: 'A dark purple berry'),
  ListItem(title: 'Fig', description: 'A soft sweet fruit'),
  ListItem(title: 'Grape', description: 'Grows in clusters'),
  ListItem(title: 'Honeydew', description: 'A pale green melon'),
  ListItem(title: 'Jackfruit', description: 'A large tropical fruit'),
  ListItem(title: 'Kiwi', description: 'A fuzzy brown fruit'),
  ListItem(title: 'Lemon', description: 'A tart yellow citrus'),
  ListItem(title: 'Mango', description: 'A sweet tropical fruit'),
];

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(_AppModel());
}

final class _AppModel extends TeaModel {
  _AppModel({ListModel? list, this.selected = ''})
      : list = list ??
            ListModel(
              items: _items,
              title: 'Fruit Picker',
              height: 8,
              showDescription: true,
              showStatusBar: true,
            );

  final ListModel list;
  final String selected;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          if (!list.filterMode) return (this, () => quit());
        case 'enter':
          if (!list.filterMode) {
            final item = list.selected;
            if (item != null) {
              return (_AppModel(list: list, selected: item.title), null);
            }
          }
      }
    }

    final (nextList, cmd) = list.update(msg);
    return (_AppModel(list: nextList as ListModel, selected: selected), cmd);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.write(list.view().content);
    b.writeln();
    if (selected.isNotEmpty) {
      b.writeln(const Style(
        foregroundRgb: RgbColor(166, 227, 161),
        isBold: true,
      ).render('  Selected: $selected'));
      b.writeln();
    }
    b.writeln(const Style(
      foregroundRgb: RgbColor(88, 91, 112),
      isDim: true,
    ).render('  ↑/↓ navigate  •  / filter  •  Enter select  •  q quit'));
    return newView(b.toString());
  }
}
