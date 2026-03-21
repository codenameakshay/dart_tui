// Run: fvm dart run example/simple.dart
// Shows a 5-second countdown using tick(). When it hits 0, quits automatically.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(CountdownModel());
}

final class _TickMsg extends Msg {}

final class CountdownModel extends TeaModel {
  CountdownModel({this.count = 5});

  final int count;

  @override
  Cmd? init() => tick(const Duration(seconds: 1), (_) => _TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _TickMsg) {
      final next = count - 1;
      if (next <= 0) {
        return (CountdownModel(count: 0), () => quit());
      }
      return (
        CountdownModel(count: next),
        tick(const Duration(seconds: 1), (_) => _TickMsg()),
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
  View view() => newView('Ticks: $count\n\nPress q to quit.');
}
