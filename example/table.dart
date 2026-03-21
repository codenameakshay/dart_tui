// Run: fvm dart run example/table.dart
// TableModel with city data. Arrow keys to navigate, q to quit.

import 'package:dart_tui/dart_tui.dart';

final _columns = [
  const TableColumn(title: 'City', width: 20),
  const TableColumn(title: 'Country', width: 20),
  const TableColumn(title: 'Population', width: 12),
];

final _rows = [
  ['Tokyo', 'Japan', '13,960,000'],
  ['Delhi', 'India', '16,787,941'],
  ['Shanghai', 'China', '24,183,300'],
  ['São Paulo', 'Brazil', '11,253,503'],
  ['Mexico City', 'Mexico', '9,209,944'],
  ['Cairo', 'Egypt', '10,107,125'],
  ['Mumbai', 'India', '20,667,656'],
  ['Beijing', 'China', '21,542,000'],
  ['Dhaka', 'Bangladesh', '8,906,035'],
  ['Osaka', 'Japan', '2,691,742'],
];

Future<void> main() async {
  await Program().run(TableExampleModel());
}

final class TableExampleModel extends TeaModel {
  TableExampleModel({TableModel? table})
      : table = table ??
            TableModel(
              columns: _columns,
              rows: _rows,
              height: 12,
            );

  final TableModel table;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
      final (updated, cmd) = table.update(msg);
      return (TableExampleModel(table: updated as TableModel), cmd);
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer('World Cities\n\n');
    b.writeln(table.view().content);
    b.writeln('\nUp/down to navigate, q to quit.');
    return newView(b.toString());
  }
}
