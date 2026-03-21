// Single animated SpinnerModel.
// Run: fvm dart run example/spinner.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(SpinnerDemoModel());
}

final class SpinnerDemoModel extends TeaModel {
  SpinnerDemoModel({SpinnerModel? spinner})
      : spinner = spinner ??
            SpinnerModel(
              prefix: 'Loading ',
            );

  final SpinnerModel spinner;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (next, cmd) = spinner.update(msg);
      return (
        SpinnerDemoModel(spinner: next as SpinnerModel),
        cmd,
      );
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
  View view() {
    final b = StringBuffer();
    b.writeln(spinner.view().content);
    b.writeln();
    b.writeln('Press q or ctrl+c to quit.');
    return newView(b.toString());
  }
}
