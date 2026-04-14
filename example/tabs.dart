// Tabbed interface — demonstrates the TabsModel bubble.
// Run: fvm dart run example/tabs.dart

import 'package:dart_tui/dart_tui.dart';

const _tabs = [
  (
    'Home',
    '''Welcome to the Home tab!

  • View your recent activity
  • Check notifications
  • Quick-access favorites
''',
  ),
  (
    'Profile',
    '''Profile

  Name:    Alice Example
  Email:   alice@example.com
  Role:    Developer
  Joined:  2024-01-01
''',
  ),
  (
    'Settings',
    '''Settings

  Theme:       Dark
  Font size:   14px
  Auto-save:   On
  Notifications: Enabled
''',
  ),
];

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(_AppModel());
}

final class _AppModel extends TeaModel {
  _AppModel({TabsModel? tabs}) : tabs = tabs ?? TabsModel(tabs: _tabs);

  final TabsModel tabs;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    final (next, cmd) = tabs.update(msg);
    return (_AppModel(tabs: next as TabsModel), cmd);
  }

  @override
  View view() {
    return newView('''${tabs.view().content}

Left/Right or Tab to switch  ·  q to quit
''');
  }
}
