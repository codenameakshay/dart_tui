// Bubble Tea shopping-list tutorial ported to dart_tui.
// Run from package root: dart run example/shopping_list.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(
    ShoppingModel(
      choices: ['Buy carrots', 'Buy celery', 'Buy kohlrabi'],
    ),
  );
}

final class ShoppingModel extends TeaModel {
  ShoppingModel({
    required this.choices,
    this.cursor = 0,
    Set<int>? selected,
  }) : selected = selected ?? <int>{};

  final List<String> choices;
  final int cursor;
  final Set<int> selected;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) {
      return (this, null);
    }
    if (msg is! KeyMsg) {
      return (this, null);
    }
    switch (msg.key) {
      case 'ctrl+c':
      case 'q':
        return (this, () => quit());
      case 'up':
      case 'k':
        final c = cursor > 0 ? cursor - 1 : 0;
        return (
          ShoppingModel(choices: choices, cursor: c, selected: selected),
          null,
        );
      case 'down':
      case 'j':
        final c = cursor < choices.length - 1 ? cursor + 1 : choices.length - 1;
        return (
          ShoppingModel(choices: choices, cursor: c, selected: selected),
          null,
        );
      case 'enter':
      case ' ':
        final next = Set<int>.from(selected);
        if (next.contains(cursor)) {
          next.remove(cursor);
        } else {
          next.add(cursor);
        }
        return (
          ShoppingModel(
            choices: choices,
            cursor: cursor,
            selected: next,
          ),
          null,
        );
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final b = StringBuffer('What should we buy at the market?\n\n');
    for (var i = 0; i < choices.length; i++) {
      final cur = cursor == i ? '>' : ' ';
      final mark = selected.contains(i) ? 'x' : ' ';
      b.writeln('$cur [$mark] ${choices[i]}');
    }
    b
      ..writeln()
      ..writeln('Press space/enter to toggle, q or ctrl+c to quit.');
    return newView(b.toString());
  }
}
