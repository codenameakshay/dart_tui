// Multi-select checkbox list — demonstrates MultiSelectModel.
// Navigate with ↑↓/jk, Space/x to toggle, a to toggle all, Enter to confirm.
// Run: fvm dart run example/multi_select.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(_MultiSelectDemoModel());
}

final class _MultiSelectDemoModel extends TeaModel {
  _MultiSelectDemoModel({MultiSelectModel? multi, this.confirmed = false})
      : multi = multi ??
            MultiSelectModel(
              title: 'Pick your favourite languages',
              items: [
                const MultiSelectItem(label: 'Dart',   value: 'dart'),
                const MultiSelectItem(label: 'Go',     value: 'go'),
                const MultiSelectItem(label: 'Rust',   value: 'rust'),
                const MultiSelectItem(label: 'Python', value: 'python'),
                const MultiSelectItem(label: 'TypeScript', value: 'ts'),
                const MultiSelectItem(label: 'Kotlin', value: 'kotlin'),
                const MultiSelectItem(label: 'Swift',  value: 'swift'),
              ],
              height: 10,
              showStatusBar: true,
              wrap: true,
            );

  final MultiSelectModel multi;
  final bool confirmed;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case 'enter':
          return (
            _MultiSelectDemoModel(multi: multi, confirmed: true),
            null,
          );
      }
    }
    final (next, cmd) = multi.update(msg);
    return (_MultiSelectDemoModel(multi: next as MultiSelectModel), cmd);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.write(multi.view().content);
    b.writeln();
    b.writeln();
    if (confirmed && multi.selected.isNotEmpty) {
      final values = multi.selectedValues.join(', ');
      b.write(const Style(
        foregroundRgb: RgbColor(166, 227, 161), // Green
        isBold: true,
      ).render('  Selected: $values'));
      b.writeln();
    } else {
      b.write(const Style(
        foregroundRgb: RgbColor(88, 91, 112), // Surface2
        isDim: true,
      ).render('  Space/x toggle · a toggle all · Enter confirm · q quit'));
    }
    return newView(b.toString());
  }
}
