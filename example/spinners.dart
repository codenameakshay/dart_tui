// All 12 spinner presets at once, each at its own speed.
// Each spinner has an id and runs its own tick chain: no withTickInterval.
// Run: dart run example/spinners.dart

import 'package:dart_tui/dart_tui.dart';

const _presets = {
  'Line': Spinner.line,
  'Dot': Spinner.dot,
  'MiniDot': Spinner.miniDot,
  'Jump': Spinner.jump,
  'Pulse': Spinner.pulse,
  'Points': Spinner.points,
  'Globe': Spinner.globe,
  'Moon': Spinner.moon,
  'Monkey': Spinner.monkey,
  'Meter': Spinner.meter,
  'Hamburger': Spinner.hamburger,
  'Ellipsis': Spinner.ellipsis,
};

Future<void> main() async {
  await Program(options: [withAltScreen()]).run(SpinnersModel());
}

final class SpinnersModel extends Model {
  SpinnersModel({List<SpinnerModel>? spinners})
      : spinners = spinners ??
            [
              for (final MapEntry(key: name, value: s) in _presets.entries)
                SpinnerModel(
                  spinner: s,
                  id: name,
                  prefix: '${name.padRight(10)}'
                      '${'${s.interval.inMilliseconds} ms'.padLeft(7)}   ',
                ),
            ];

  final List<SpinnerModel> spinners;

  @override
  Cmd? init() => batch([for (final s in spinners) s.tick()]);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final next = <SpinnerModel>[];
      final cmds = <Cmd?>[];
      for (final s in spinners) {
        final (updated, cmd) = s.update(msg);
        next.add(updated as SpinnerModel);
        cmds.add(cmd);
      }
      return (SpinnersModel(spinners: next), batch(cmds));
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
    b.writeln('Spinner presets, each at its own speed:\n');
    for (final s in spinners) {
      b.writeln('  ${s.view().content}');
    }
    b.writeln('\nPress q or ctrl+c to quit.');
    return newView(b.toString());
  }
}
