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
    if (scenario != 'stdin-quit' &&
        scenario != 'stdin-default-reuse' &&
        scenario != 'normal-screen-stdin-quit' &&
        scenario != 'view-alt-screen-stdin-quit')
      withInput(null),
    if (scenario != 'normal-screen-stdin-quit' &&
        scenario != 'view-alt-screen-stdin-quit')
      withAltScreen(),
    withHideCursor(),
    if (scenario != 'resize') withoutSignalHandler(),
    if (scenario == 'normal-screen-stdin-quit') withWindowSize(80, 5),
    if (scenario == 'cancel')
      withContext(
          () => Future<void>.delayed(const Duration(milliseconds: 250))),
  ];
  program = Program(options: options);

  Timer? killTimer;
  if (scenario == 'kill') {
    killTimer = Timer(const Duration(milliseconds: 250), program.kill);
  }
  if (scenario == 'stdin-default-reuse') {
    await _runDefaultStdinReuseProbe();
    return;
  }
  await program.run(_ProbeModel(scenario));
  killTimer?.cancel();
}

const _scenarios = {
  'kill',
  'cancel',
  'resize',
  'suspend',
  'stdin-default-reuse',
  'stdin-quit',
  'normal-screen-stdin-quit',
  'view-alt-screen-stdin-quit',
};

Future<void> _runDefaultStdinReuseProbe() async {
  await Program(
    options: [withAltScreen(), withHideCursor(), withoutSignalHandler()],
  ).run(const _ProbeModel('stdin-default-reuse-first'));
  try {
    await Program(
      options: [withAltScreen(), withHideCursor(), withoutSignalHandler()],
    ).run(const _ProbeModel('stdin-default-reuse-second'));
    throw StateError('second implicit stdin program unexpectedly ran');
  } on StateError catch (error) {
    final message = error.message.toString();
    if (!message.contains('Implicit stdin supports one Program lifecycle')) {
      rethrow;
    }
    stdout.writeln('STDIN_DEFAULT_REUSE_BLOCKED');
  }
}

final class _ProbeModel implements Model {
  const _ProbeModel(this.scenario, [this.state]);

  final String scenario;
  final String? state;

  @override
  Cmd? init() {
    if (scenario == 'stdin-default-reuse-first') return _delayedQuit();
    if (scenario == 'stdin-quit') return _delayedQuit();
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
    if (scenario == 'normal-screen-stdin-quit' &&
        msg is KeyMsg &&
        msg.key == 'q') {
      return (_ProbeModel(scenario, 'NORMAL_SCREEN_EXITING'), () => QuitMsg());
    }
    if (scenario == 'view-alt-screen-stdin-quit' &&
        msg is KeyMsg &&
        msg.key == 'q') {
      return (
        _ProbeModel(scenario, 'VIEW_ALT_SCREEN_EXITING'),
        () => QuitMsg()
      );
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
              'stdin-default-reuse-first' => 'STDIN_DEFAULT_REUSE_FIRST',
              'stdin-default-reuse-second' => 'STDIN_DEFAULT_REUSE_SECOND',
              'stdin-quit' => 'STDIN_QUIT_READY',
              'normal-screen-stdin-quit' =>
                'NORMAL_SCREEN_READY\nline two\nline three',
              'view-alt-screen-stdin-quit' => 'VIEW_ALT_SCREEN_READY',
              _ => throw StateError('unsupported probe scenario: $scenario'),
            },
        altScreen: scenario != 'normal-screen-stdin-quit',
      );
}

Cmd _delayedQuit() => () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return QuitMsg();
    };
