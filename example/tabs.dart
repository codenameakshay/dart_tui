// Tabbed interface with 3 tabs.
// Run: fvm dart run example/tabs.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(TabsModel());
}

const _tabNames = ['Home', 'Profile', 'Settings'];

final class TabsModel extends TeaModel {
  TabsModel({this.activeTab = 0});

  final int activeTab;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'left':
      case 'h':
        final next = activeTab > 0 ? activeTab - 1 : 0;
        return (TabsModel(activeTab: next), null);
      case 'right':
      case 'l':
        final next = activeTab < _tabNames.length - 1
            ? activeTab + 1
            : _tabNames.length - 1;
        return (TabsModel(activeTab: next), null);
      case 'tab':
        final next = (activeTab + 1) % _tabNames.length;
        return (TabsModel(activeTab: next), null);
      case 'q':
      case 'ctrl+c':
        return (this, () => quit());
    }
    return (this, null);
  }

  String _tabBar() {
    final b = StringBuffer();
    for (var i = 0; i < _tabNames.length; i++) {
      if (i == activeTab) {
        b.write(
          ' ${TuiStyle.bold}\x1b[4m${_tabNames[i]}${TuiStyle.reset} ',
        );
      } else {
        b.write(' ${TuiStyle.dim}${_tabNames[i]}${TuiStyle.reset} ');
      }
      if (i < _tabNames.length - 1) b.write('│');
    }
    return b.toString();
  }

  String _tabContent() {
    switch (activeTab) {
      case 0:
        return '''
Welcome to the Home tab!

  • View your recent activity
  • Check notifications
  • Quick-access favorites
''';
      case 1:
        return '''
Profile

  Name:    Alice Example
  Email:   alice@example.com
  Role:    Developer
  Joined:  2024-01-01
''';
      case 2:
        return '''
Settings

  Theme:       Dark
  Font size:   14px
  Auto-save:   On
  Notifications: Enabled
''';
      default:
        return '(unknown tab)';
    }
  }

  @override
  View view() {
    final bar = _tabBar();
    final divider = '─' * 40;
    final content = _tabContent();
    return newView('''
Tabs demo

$bar
$divider

$content
Left/Right or Tab to switch · q to quit
''');
  }
}
