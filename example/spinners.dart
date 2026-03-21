// Show all spinner frame styles simultaneously.
// Run: fvm dart run example/spinners.dart

import 'package:dart_tui/dart_tui.dart';

const _dotFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const _lineFrames = ['-', r'\', '|', '/'];
const _moonFrames = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'];
const _hamburgerFrames = ['☱', '☲', '☴'];
const _clockFrames = [
  '🕐',
  '🕑',
  '🕒',
  '🕓',
  '🕔',
  '🕕',
  '🕖',
  '🕗',
  '🕘',
  '🕙',
  '🕚',
  '🕛',
];
const _bounceFrames = ['.  ', '.. ', '...'];

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 120),
    ),
  ).run(SpinnersModel());
}

final class SpinnersModel extends TeaModel {
  SpinnersModel({List<SpinnerModel>? spinners})
      : spinners = spinners ??
            [
              SpinnerModel(frames: _dotFrames, prefix: 'Dot      '),
              SpinnerModel(frames: _lineFrames, prefix: 'Line     '),
              SpinnerModel(frames: _moonFrames, prefix: 'Moon     '),
              SpinnerModel(frames: _hamburgerFrames, prefix: 'Hamburger'),
              SpinnerModel(frames: _clockFrames, prefix: 'Clock    '),
              SpinnerModel(frames: _bounceFrames, prefix: 'Bounce   '),
            ];

  final List<SpinnerModel> spinners;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final next = spinners.map((s) {
        final (updated, _) = s.update(msg);
        return updated as SpinnerModel;
      }).toList();
      return (SpinnersModel(spinners: next), null);
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
    b.writeln('Spinner styles:\n');
    for (final s in spinners) {
      b.writeln('  ${s.view().content}');
    }
    b.writeln('\nPress q or ctrl+c to quit.');
    return newView(b.toString());
  }
}
