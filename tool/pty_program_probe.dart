import 'dart:async';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main(List<String> arguments) async {
  if (!Platform.isLinux && !Platform.isMacOS) {
    stderr.writeln('PTY program probe requires a Unix host');
    exitCode = 64;
    return;
  }
  if (arguments.length != 1 || !_scenarios.contains(arguments.single)) {
    stderr.writeln('usage: pty_program_probe.dart <${_scenarios.join('|')}>');
    exitCode = 64;
    return;
  }

  final scenario = arguments.single;
  late final Program program;
  final options = <ProgramOption>[
    withInput(null),
    withAltScreen(),
    withHideCursor(),
    if (scenario != 'resize') withoutSignalHandler(),
    if (scenario == 'cancel')
      withContext(
          () => Future<void>.delayed(const Duration(milliseconds: 250))),
  ];
  program = Program(programOptions: options);

  Timer? killTimer;
  if (scenario == 'kill') {
    killTimer = Timer(const Duration(milliseconds: 250), program.kill);
  }
  await program.run(_ProbeModel(scenario));
  killTimer?.cancel();
}

const _scenarios = {'kill', 'cancel', 'resize', 'suspend'};

final class _ProbeModel implements Model {
  const _ProbeModel(this.scenario, [this.state]);

  final String scenario;
  final String? state;

  @override
  Cmd? init() {
    if (scenario != 'suspend') return null;
    return () async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return SuspendMsg();
    };
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (scenario == 'resize' &&
        msg is WindowSizeMsg &&
        msg.width == 101 &&
        msg.height == 37) {
      return (
        _ProbeModel(scenario, 'RESIZED:101x37'),
        _delayedQuit(),
      );
    }
    if (scenario == 'suspend' && msg is ResumeMsg) {
      return (_ProbeModel(scenario, 'RESUMED'), _delayedQuit());
    }
    return (this, null);
  }

  @override
  View view() => View(
        content: state ??
            switch (scenario) {
              'kill' => 'KILL_READY',
              'cancel' => 'CANCEL_READY',
              'resize' => 'RESIZE_READY',
              'suspend' => 'SUSPEND_READY',
              _ => throw StateError('unsupported probe scenario: $scenario'),
            },
        altScreen: true,
      );
}

Cmd _delayedQuit() => () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return QuitMsg();
    };
