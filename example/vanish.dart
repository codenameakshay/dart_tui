// Run: fvm dart run example/vanish.dart
// Single keystroke then quit. Alt-screen means no output remains.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(VanishModel());
}

final class VanishModel extends TeaModel {
  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView('Press any key to vanish...');
}
