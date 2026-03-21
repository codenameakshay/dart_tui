// Ported from charmbracelet/bubbletea examples/sequence
import 'package:dart_tui/dart_tui.dart';

final class _LineMsg extends Msg {
  _LineMsg(this.text);
  final String text;
}

Future<void> main() async {
  await Program().run(SequenceModel());
}

final class SequenceModel extends TeaModel {
  SequenceModel({this.lines = const [], this.done = false});
  final List<String> lines;
  final bool done;

  static Cmd _delayed(String text, Duration delay) => () async {
        await Future<void>.delayed(delay);
        return _LineMsg(text);
      };

  @override
  Cmd? init() => batch([
        // sequence: these run in order
        sequence([
          _delayed(
            'sequence: step 1 (200ms delay)',
            const Duration(milliseconds: 200),
          ),
          _delayed(
            'sequence: step 2 (100ms delay)',
            const Duration(milliseconds: 100),
          ),
          _delayed(
            'sequence: step 3 (50ms delay)',
            const Duration(milliseconds: 50),
          ),
        ]),
        // batch: these run concurrently
        batch([
          _delayed(
            'batch: task A (300ms delay)',
            const Duration(milliseconds: 300),
          ),
          _delayed(
            'batch: task B (100ms delay)',
            const Duration(milliseconds: 100),
          ),
          _delayed(
            'batch: task C (150ms delay)',
            const Duration(milliseconds: 150),
          ),
        ]),
      ]);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
    }
    if (msg is _LineMsg) {
      final next = [...lines, msg.text];
      return (SequenceModel(lines: next, done: next.length >= 6), null);
    }
    return (this, null);
  }

  @override
  View view() {
    final header = const Style().bold().render('Sequence vs Batch');
    final b = StringBuffer('$header\n\n');
    b.writeln(
      'sequence() runs commands in order (waits for each to finish)',
    );
    b.writeln('batch() runs commands concurrently (all start at once)\n');
    for (final line in lines) {
      b.writeln('  ✓ $line');
    }
    if (done) {
      b.write(
        '\nNote how batch tasks completed out-of-order by delay!\n\nq: quit',
      );
    } else {
      b.write('\nWaiting for commands...');
    }
    return newView(b.toString());
  }
}
