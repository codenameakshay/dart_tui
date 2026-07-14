// Run: fvm dart run example/window_size.dart
// Shows terminal dimensions, updates on resize. Press q to quit.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(WindowSizeModel());
}

final class WindowSizeModel extends TeaModel {
  WindowSizeModel({this.width = 0, this.height = 0});

  final int width;
  final int height;

  @override
  Cmd? init() => () => requestWindowSize();

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg) {
      return (WindowSizeModel(width: msg.width, height: msg.height), null);
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() => newView('Terminal: ${width}x$height\n\nPress q to quit.');
}
