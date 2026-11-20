/// A checklist that fills the terminal: a list, a help bar and quit keys.
library;

import 'package:dart_tui/dart_tui.dart';

/// The keys the app answers to. The help bar is built from them.
final class AppKeys implements KeyMap {
  const AppKeys();

  static const up = KeyBinding(
    keys: ['up', 'k'],
    help: (key: '↑/k', description: 'up'),
  );
  static const down = KeyBinding(
    keys: ['down', 'j'],
    help: (key: '↓/j', description: 'down'),
  );
  static const check = KeyBinding(
    keys: ['enter', 'space'],
    help: (key: 'enter', description: 'check'),
  );
  static const quit = KeyBinding(
    keys: ['q', 'esc', 'ctrl+c'],
    help: (key: 'q', description: 'quit'),
  );

  @override
  List<KeyBinding> get bindings => [up, down, check, quit];
}

const _title = Style(isBold: true, foreground256: 13);
const _helpBar = Style(isDim: true);

/// The app's state. Every update returns a new [AppModel].
final class AppModel extends Model {
  AppModel({
    this.items = const [
      'Run the app',
      'Read lib/__name__.dart',
      'Add an item to this list',
      'Run dart test',
    ],
    this.checked = const {},
    this.cursor = 0,
  });

  final List<String> items;

  /// The indexes of the checked items.
  final Set<int> checked;
  final int cursor;

  AppModel _copy({Set<int>? checked, int? cursor}) => AppModel(
        items: items,
        checked: checked ?? this.checked,
        cursor: cursor ?? this.cursor,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    if (AppKeys.quit.matches(msg)) return (this, () => quit());
    if (items.isEmpty) return (this, null);
    if (AppKeys.check.matches(msg)) {
      final next = {...checked};
      if (!next.remove(cursor)) next.add(cursor);
      return (_copy(checked: next), null);
    }
    // The list moves its cursor on up/down and k/j.
    final (list, cmd) = _list.update(msg);
    return (_copy(cursor: (list as SelectListModel).cursor), cmd);
  }

  SelectListModel get _list => SelectListModel(
        items: [
          for (final (i, item) in items.indexed)
            '[${checked.contains(i) ? 'x' : ' '}] $item',
        ],
        cursor: cursor,
      );

  @override
  View view() {
    final help = [
      for (final binding in const AppKeys().bindings)
        '${binding.help.key} ${binding.help.description}',
    ].join(' • ');
    return newView(
      '${_title.render('Checklist')}\n\n'
      '${items.isEmpty ? '' : _list.view().content}\n'
      '${_helpBar.render(help)}',
    );
  }
}
