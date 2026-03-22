// Composable views: TimerModel (5s countdown) + SpinnerModel side by side.
// Tab switches focus between them.
// Run: fvm dart run example/composable_views.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(_ComposableModel());
}

enum _Focus { timer, spinner }

final class _ComposableModel extends TeaModel {
  _ComposableModel({
    TimerModel? timer,
    SpinnerModel? spinner,
    this.focus = _Focus.timer,
  })  : timer = timer ??
            TimerModel(
              duration: const Duration(seconds: 5),
              running: true,
            ),
        spinner = spinner ??
            SpinnerModel(
              prefix: 'Working ',
              frames: const ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
            );

  final TimerModel timer;
  final SpinnerModel spinner;
  final _Focus focus;

  _ComposableModel _copyWith({
    TimerModel? timer,
    SpinnerModel? spinner,
    _Focus? focus,
  }) =>
      _ComposableModel(
        timer: timer ?? this.timer,
        spinner: spinner ?? this.spinner,
        focus: focus ?? this.focus,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (nextTimer, _) = timer.update(msg);
      final (nextSpinner, _) = spinner.update(msg);
      return (
        _copyWith(
          timer: nextTimer as TimerModel,
          spinner: nextSpinner as SpinnerModel,
        ),
        null,
      );
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'tab':
          return (
            _copyWith(
              focus: focus == _Focus.timer ? _Focus.spinner : _Focus.timer,
            ),
            null,
          );
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final timerActive = focus == _Focus.timer;
    final spinnerActive = focus == _Focus.spinner;

    final timerLabel =
        timerActive ? '${TuiStyle.bold}[Timer]${TuiStyle.reset}' : ' Timer ';
    final spinnerLabel = spinnerActive
        ? '${TuiStyle.bold}[Spinner]${TuiStyle.reset}'
        : ' Spinner ';

    final timerContent = '$timerLabel\n${timer.view().content}';
    final spinnerContent = '$spinnerLabel\n${spinner.view().content}';

    final combined =
        joinHorizontal(0.0, [timerContent, '    ', spinnerContent]);

    return newView('''
Composable views demo

$combined

Tab to switch focus · q to quit
''');
  }
}
