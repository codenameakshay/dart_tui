// Run: fvm dart run example/set_window_title.dart
// Demonstrates View.windowTitle. Press any key to see it; q to quit.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(WindowTitleModel());
}

final class WindowTitleModel extends TeaModel {
  WindowTitleModel({this.lastKey = ''});

  final String lastKey;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        default:
          return (WindowTitleModel(lastKey: msg.key), null);
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final content = lastKey.isEmpty
        ? 'Press any key (q to quit).'
        : 'Last key: $lastKey\n\nPress q to quit.';
    final v = newView(content);
    v.windowTitle = 'dart_tui demo';
    return v;
  }
}
