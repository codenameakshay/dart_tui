// Background async work demo using init() Cmd.
// Run: fvm dart run example/realtime.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(RealtimeModel());
}

final class _DoneMsg extends Msg {
  _DoneMsg(this.result);
  final String result;
}

final class RealtimeModel extends TeaModel {
  RealtimeModel({
    this.result,
    SpinnerModel? spinner,
  }) : spinner = spinner ?? SpinnerModel(prefix: 'Working... ');

  final String? result;
  final SpinnerModel spinner;

  @override
  Cmd? init() => () async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return _DoneMsg('Background work complete!');
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _DoneMsg) {
      return (RealtimeModel(result: msg.result, spinner: spinner), null);
    }
    if (msg is TickMsg && result == null) {
      final (next, _) = spinner.update(msg);
      return (
        RealtimeModel(result: result, spinner: next as SpinnerModel),
        null
      );
    }
    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.writeln('Realtime background work demo');
    b.writeln();
    if (result == null) {
      b.writeln(spinner.view().content);
      b.writeln();
      b.writeln('(background task started — waiting 3 seconds...)');
    } else {
      b.writeln('Result: $result');
    }
    b.writeln();
    b.write('Press q or ctrl+c to quit.');
    return newView(b.toString());
  }
}
