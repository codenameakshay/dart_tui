// ProgressModel with arrow-key control.
// Run: fvm dart run example/progress_bar.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(ProgressBarModel());
}

final class ProgressBarModel extends TeaModel {
  ProgressBarModel({this.fraction = 0.5});

  final double fraction;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'left':
      case 'h':
        final next = (fraction - 0.1).clamp(0.0, 1.0);
        return (ProgressBarModel(fraction: next), null);
      case 'right':
      case 'l':
        final next = (fraction + 0.1).clamp(0.0, 1.0);
        return (ProgressBarModel(fraction: next), null);
      case 'q':
      case 'ctrl+c':
        return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() {
    final bar = ProgressModel(fraction: fraction, width: 40, label: 'progress')
        .view()
        .content;
    return newView('''
Progress bar demo

$bar

Left/Right (or h/l) to adjust · q to quit
''');
  }
}
