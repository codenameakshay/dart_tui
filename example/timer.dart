// 1-minute countdown TimerModel demo.
// Run: fvm dart run example/timer.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(TimerApp());
}

final class TimerApp extends TeaModel {
  TimerApp({TimerModel? timer})
      : timer = timer ?? TimerModel(duration: const Duration(minutes: 1));

  final TimerModel timer;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (next, cmd) = timer.update(msg);
      return (TimerApp(timer: next as TimerModel), cmd);
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 's':
          final next = timer.running ? timer.stop() : timer.start();
          return (TimerApp(timer: next), null);
        case 'r':
          return (TimerApp(timer: timer.reset()), null);
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final status = timer.finished
        ? 'Finished!'
        : timer.running
            ? 'Running'
            : 'Stopped';

    final b = StringBuffer();
    b.writeln('1-Minute Countdown Timer');
    b.writeln();
    b.writeln('  Time remaining: ${timer.view().content}');
    b.writeln('  Status        : $status');
    b.writeln();
    b.write('s: start/stop  r: reset  q: quit');
    return newView(b.toString());
  }
}
