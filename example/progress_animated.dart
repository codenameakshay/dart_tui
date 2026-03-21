// Auto-incrementing animated progress bar.
// Run: fvm dart run example/progress_animated.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(ProgressAnimatedModel());
}

final class _TickMsg extends Msg {}

final class ProgressAnimatedModel extends TeaModel {
  ProgressAnimatedModel({this.fraction = 0.0, this.done = false});

  final double fraction;
  final bool done;

  @override
  Cmd? init() => tick(const Duration(milliseconds: 100), (_) => _TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _TickMsg) {
      if (done) return (this, null);
      final next = fraction + 0.02;
      if (next >= 1.0) {
        return (ProgressAnimatedModel(fraction: 1.0, done: true), null);
      }
      return (
        ProgressAnimatedModel(fraction: next),
        tick(const Duration(milliseconds: 100), (_) => _TickMsg()),
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
    if (done) {
      return newView('''
Download complete!

${ProgressModel(fraction: 1.0, width: 40, label: 'download').view().content}

Done! Press q to quit.
''');
    }

    final bar = ProgressModel(fraction: fraction, width: 40, label: 'download')
        .view()
        .content;
    return newView('''
Downloading...

$bar

Press q to quit at any time.
''');
  }
}
