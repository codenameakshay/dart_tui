// Demonstrates Program.send() from an external timer.
// Run: fvm dart run example/send_msg.dart

import 'dart:async';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  final program = Program(options: const ProgramOptions(altScreen: true));
  var count = 0;
  final t = Timer.periodic(const Duration(milliseconds: 500), (_) {
    count++;
    program.send(_CountMsg(count));
  });
  await program.run(_CounterModel());
  t.cancel();
}

final class _CountMsg extends Msg {
  _CountMsg(this.n);
  final int n;
}

final class _CounterModel extends TeaModel {
  _CounterModel({this.count = 0});

  final int count;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _CountMsg) return (_CounterModel(count: msg.n), null);
    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView(
        'External tick count: $count\n\nMessages sent via program.send() every 500 ms.\n\nPress q or ctrl+c to quit.',
      );
}
