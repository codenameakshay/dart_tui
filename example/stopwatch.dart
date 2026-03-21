// StopwatchModel elapsed time demo.
// Run: fvm dart run example/stopwatch.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 10),
    ),
  ).run(StopwatchApp());
}

final class StopwatchApp extends TeaModel {
  StopwatchApp({StopwatchModel? stopwatch})
      : stopwatch = stopwatch ?? StopwatchModel();

  final StopwatchModel stopwatch;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (next, cmd) = stopwatch.update(msg);
      return (StopwatchApp(stopwatch: next as StopwatchModel), cmd);
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 's':
          final next = stopwatch.running ? stopwatch.stop() : stopwatch.start();
          return (StopwatchApp(stopwatch: next), null);
        case 'r':
          return (StopwatchApp(stopwatch: stopwatch.reset()), null);
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final status = stopwatch.running ? 'Running' : 'Stopped';
    final b = StringBuffer();
    b.writeln('Stopwatch');
    b.writeln();
    b.writeln('  Elapsed : ${stopwatch.view().content}');
    b.writeln('  Status  : $status');
    b.writeln();
    b.write('s: start/stop  r: reset  q: quit');
    return newView(b.toString());
  }
}
