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
  if (scenario == 'default-chain') {
    // Sequential programs share the implicit process stdin.
    for (final step in ['chain-one', 'chain-two']) {
      await Program(options: [withAltScreen(), withHideCursor()])
          .run(_ProbeModel(step));
    }
    stdout.writeln('CHAIN_DONE');
    return;
  }
  if (scenario == 'default-exec-chain') {
    final program = Program(options: [withAltScreen(), withHideCursor()]);
    await program.run(_ProbeModel(scenario));
    stdout.writeln('EXEC_FIRST_DONE');
    await stdout.flush();
    // Leave a deterministic cooked-mode observation window before the next
    // Program enters raw mode.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await Program(options: [withAltScreen(), withHideCursor()])
        .run(const _ProbeModel('exec-followup'));
    return;
  }
  // `default-*` scenarios read the implicit process stdin with the default
  // signal handling, like a real application.
  final usesDefaults = scenario.startsWith('default-');
  late final Program program;
  final options = <ProgramOption>[
    if ({'stdin-quit', 'stdin-ctrl-c'}.contains(scenario))
      withInput(stdin)
    else if (!usesDefaults)
      withInput(null),
    withAltScreen(),
    withHideCursor(),
    if (!usesDefaults && !{'resize', 'stdin-ctrl-c'}.contains(scenario))
      withoutSignalHandler(),
    if (scenario == 'cancel')
      withContext(
          () => Future<void>.delayed(const Duration(milliseconds: 250))),
  ];
  program = Program(options: options);

  Timer? killTimer;
  if (scenario == 'kill') {
    killTimer = Timer(const Duration(milliseconds: 250), program.kill);
  }
  await program.run(_ProbeModel(scenario));
  killTimer?.cancel();
}

const _scenarios = {
  'kill',
  'cancel',
  'resize',
  'suspend',
  'stdin-quit',
  'stdin-ctrl-c',
  'default-quit',
  'default-chain',
  'default-keys',
  'default-suspend',
  'default-term',
  'default-exec',
  'default-exec-chain',
  'default-init-exec',
};

final class _ProbeModel implements Model {
  const _ProbeModel(this.scenario, [this.state]);

  final String scenario;
  final String? state;

  @override
  Cmd? init() {
    if (scenario == 'default-init-exec') {
      return execProcess(
        '/bin/sh',
        ['-c', r'printf "INIT_EXEC_CHILD\n"'],
        onExit: (_) => quit(),
      );
    }
    if (scenario != 'suspend') return null;
    return () async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return SuspendMsg();
    };
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if ((scenario == 'stdin-quit' || scenario == 'stdin-ctrl-c') &&
        msg is KeyMsg &&
        (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    if ((scenario == 'default-quit' ||
            scenario == 'exec-followup' ||
            scenario.startsWith('chain-')) &&
        msg is KeyMsg &&
        msg.key == 'q') {
      return (this, () => quit());
    }
    if (scenario == 'default-keys' &&
        msg is KeyMsg &&
        (msg.key == 'ctrl+z' || msg.key == 'ctrl+c')) {
      return (
        _ProbeModel(scenario, 'KEY:${msg.key}'),
        msg.key == 'ctrl+c' ? _delayedQuit() : null,
      );
    }
    if (scenario == 'default-suspend' && msg is KeyMsg) {
      if (msg.key == 'ctrl+z') return (this, suspend);
      if (msg.key == 'q') return (this, () => quit());
    }
    if ((scenario == 'default-exec' || scenario == 'default-exec-chain') &&
        msg is KeyMsg) {
      if (msg.key == 'q') return (this, () => quit());
      if (msg.key == 'x') {
        return (
          this,
          execProcess(
            '/bin/sh',
            ['-c', r'read line; echo "CHILD:$line"'],
            onExit: (code) => _ExecDoneMsg(code),
          ),
        );
      }
    }
    if (msg is _ExecDoneMsg) {
      return (_ProbeModel(scenario, 'EXEC_DONE:${msg.code}'), null);
    }
    if (scenario == 'default-suspend' && msg is ResumeMsg) {
      return (_ProbeModel(scenario, 'RESUMED'), null);
    }
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
              'stdin-quit' => 'STDIN_QUIT_READY',
              'stdin-ctrl-c' => 'STDIN_CTRL_C_READY',
              'default-quit' => 'DEFAULT_QUIT_READY',
              'chain-one' => 'CHAIN_ONE_READY',
              'chain-two' => 'CHAIN_TWO_READY',
              'default-keys' => 'DEFAULT_KEYS_READY',
              'default-suspend' => 'DEFAULT_SUSPEND_READY',
              'default-term' => 'DEFAULT_TERM_READY',
              'default-exec' => 'DEFAULT_EXEC_READY',
              'default-exec-chain' => 'DEFAULT_EXEC_READY',
              'default-init-exec' => 'DEFAULT_INIT_EXEC_READY',
              'exec-followup' => 'EXEC_FOLLOWUP_READY',
              _ => throw StateError('unsupported probe scenario: $scenario'),
            },
        altScreen: true,
      );
}

final class _ExecDoneMsg extends Msg {
  _ExecDoneMsg(this.code);
  final int code;
}

Cmd _delayedQuit() => () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return QuitMsg();
    };
