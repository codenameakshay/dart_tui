import 'dart:async';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';

import '../example/cli_logger.dart' show createProject;

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
  if (scenario.startsWith('inline')) {
    // Normal-screen programs (#18): each draws where the cursor is.
    final cell = scenario.endsWith('-cell');
    final steps = scenario.startsWith('inline-chain')
        ? const ['FIRST', 'SECOND']
        : const ['INLINE'];
    for (final step in steps) {
      await Program(options: [if (cell) withCellRenderer()]).run(
          scenario.startsWith('inline-lifecycle')
              ? _InlineLifecycleModel()
              : _InlineModel(step));
    }
    return;
  }
  if (scenario.startsWith('logger-progress-end-')) {
    final logger = Logger();
    if (scenario == 'logger-progress-end-overlap') {
      final first = logger.progress('FIRST_PROGRESS');
      final second = logger.progress('SECOND_PROGRESS');
      first.complete('FIRST_DONE');
      second.complete('SECOND_DONE');
    } else {
      final progress = logger.progress('ENDING_PROGRESS');
      switch (scenario) {
        case 'logger-progress-end-complete':
          progress.complete('ENDING_COMPLETE');
          break;
        case 'logger-progress-end-fail':
          progress.fail('ENDING_FAILED');
          break;
        case 'logger-progress-end-cancel':
          progress.cancel();
          break;
      }
    }
    return;
  }
  if (scenario == 'logger-interleave') {
    final logger = Logger();
    final progress = logger.progress('INTERLEAVE_WORK');
    logger.info('INTERLEAVE_INFO');
    logger.warn('INTERLEAVE_WARN');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    progress.fail('INTERLEAVE_FAILED');
    logger.info('INTERLEAVE_DONE');
    return;
  }
  if (scenario == 'logger-progress') {
    // A TUI prompt, then a progress that runs until Ctrl+C kills the process.
    final logger = Logger();
    final ok = await logger.confirm('LOGGER_CONFIRM');
    logger.info('LOGGER_ANSWER=$ok');
    logger.progress('LOGGER_WORKING');
    await Completer<void>().future;
  }
  if (scenario == 'logger-cancel') {
    await Logger().confirm('LOGGER_CONFIRM');
    stdout.writeln('LOGGER_NOT_CANCELLED');
    return;
  }
  if (scenario == 'logger-flow') {
    await createProject(Logger(), step: const Duration(milliseconds: 50));
    return;
  }
  if (scenario == 'plain-chain') {
    final first = await promptInput('FIRST:',
        options: [withPlainMode(), withEnvironment(const {})]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final second = await promptInput('SECOND:',
        options: [withPlainMode(), withEnvironment(const {})]);
    final third = await promptInput('THIRD:',
        options: [withPlainMode(), withEnvironment(const {})]);
    stdout.writeln('ANSWERS=$first|$second|$third');
    return;
  }
  if (scenario == 'plain-password-echo') {
    stdin.echoMode = false;
    try {
      await Form([
        Group([Field.password(key: 'secret', title: 'SECRET')]),
      ]).run(options: [withPlainMode(), withEnvironment(const {})]);
      stdout.writeln('ECHO_RESTORED=${stdin.echoMode}');
    } finally {
      stdin.echoMode = true;
    }
    return;
  }
  if (scenario == 'plain-then-tui') {
    // A plain prompt reads a line through the shared stdin owner, then a full
    // program still gets keys from the same stdin.
    final name = await promptInput('PLAIN_NAME:',
        options: [withPlainMode(), withEnvironment(const {})]);
    stdout.writeln('PLAIN_ANSWER=$name');
    await Program(options: [
      withAltScreen(),
      withHideCursor(),
      withEnvironment(const {}),
    ]).run(const _ProbeModel('plain-then-tui'));
    stdout.writeln('PLAIN_TUI_DONE');
    return;
  }
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
  if (scenario == 'default-exec-concurrent') {
    // Another program reading stdin must not take input from an exec child.
    await Future.wait([
      Program(options: [withAltScreen(), withHideCursor()])
          .run(const _ProbeModel('default-exec')),
      Program(options: [withoutRenderer()])
          .run(const _ProbeModel('exec-bystander')),
    ]);
    stdout.writeln('CONCURRENT_EXEC_DONE');
    return;
  }
  if (scenario == 'explicit-exec') {
    await Program(options: [
      withInput(stdin),
      withAltScreen(),
      withHideCursor(),
    ]).run(const _ProbeModel('explicit-exec'));
    return;
  }
  if (scenario == 'restart-suspend') {
    late final Program program;
    program = Program(options: [
      withAltScreen(),
      withHideCursor(),
      withFilter((_, msg) {
        if (msg is SuspendMsg) {
          scheduleMicrotask(() {
            program.kill();
            unawaited(program.run(_RestartReadyModel()));
          });
        }
        return msg;
      }),
    ]);
    await program.run(const _ProbeModel('suspend'));
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
  'logger-interleave',
  'logger-progress-end-complete',
  'logger-progress-end-fail',
  'logger-progress-end-cancel',
  'logger-progress-end-overlap',
  'logger-progress',
  'logger-cancel',
  'logger-flow',
  'plain-then-tui',
  'plain-chain',
  'plain-password-echo',
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
  'default-exec-concurrent',
  'default-init-exec',
  'default-init-exec-reads',
  'explicit-exec',
  'restart-suspend',
  'inline-lifecycle',
  'inline-lifecycle-cell',
  'inline',
  'inline-cell',
  'inline-chain',
  'inline-chain-cell',
};

/// A normal-screen view: `g` grows it, `s` shrinks it, `t` makes it taller
/// than the terminal (and redraws it again on every later `t`), `p` prints a
/// line above it, and `q` quits.
final class _InlineModel implements Model {
  const _InlineModel(this.name, [this.rows = 2, this.redraws = 0]);

  final String name;
  final int rows;
  final int redraws;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    return switch (msg.key) {
      'g' => (_InlineModel(name, rows + 3, redraws), null),
      's' => (_InlineModel(name, 2, redraws), null),
      't' => (_InlineModel(name, 40, redraws + 1), null),
      'p' => (this, println('${name}_PRINTED')),
      'q' => (this, () => quit()),
      _ => (this, null),
    };
  }

  @override
  View view() => newView([
        '${name}_TOP rows=$rows redraws=$redraws',
        for (var row = 1; row < rows - 1; row++)
          '${name}_ROW_${row.toString().padLeft(2, '0')} v$redraws',
        '${name}_LAST rows=$rows',
      ].join('\n'));
}

final class _InlineLifecycleModel extends Model {
  _InlineLifecycleModel({this.altScreen = false, this.revision = 0});

  final bool altScreen;
  final int revision;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _InlineExecDoneMsg) {
      return (
        _InlineLifecycleModel(altScreen: altScreen, revision: revision + 1),
        null,
      );
    }
    if (msg is! KeyMsg) return (this, null);
    return switch (msg.key) {
      'a' => (
          _InlineLifecycleModel(altScreen: !altScreen, revision: revision + 1),
          null
        ),
      'c' => (
          _InlineLifecycleModel(altScreen: altScreen, revision: revision + 1),
          clearScrollArea
        ),
      'x' => (
          this,
          execProcess('/bin/sh', ['-c', r'printf "INLINE_CHILD\n"'],
              onExit: (_) => _InlineExecDoneMsg())
        ),
      'q' => (this, () => quit()),
      _ => (this, null),
    };
  }

  @override
  View view() => View(
        content: 'LIFECYCLE_TOP v$revision\nLIFECYCLE_LAST v$revision',
        altScreen: altScreen,
      );
}

final class _InlineExecDoneMsg extends Msg {}

final class _ProbeModel implements Model {
  const _ProbeModel(this.scenario, [this.state]);

  final String scenario;
  final String? state;

  @override
  Cmd? init() {
    if (scenario == 'default-init-exec-reads') {
      // The child reads its input in cbreak mode, as an editor would, and
      // reports what it got: replies to the startup queries must not be there.
      return execProcess(
        'python3',
        [
          '-c',
          'import os, select, termios, tty\n'
              'old = termios.tcgetattr(0)\n'
              'tty.setcbreak(0, termios.TCSANOW)\n'
              'ready, _, _ = select.select([0], [], [], 0.5)\n'
              'data = os.read(0, 256) if ready else b""\n'
              'termios.tcsetattr(0, termios.TCSADRAIN, old)\n'
              'print("CHILD_GOT:" + data.hex(), flush=True)\n',
        ],
        onExit: (_) => quit(),
      );
    }
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
            scenario == 'explicit-exec' ||
            scenario == 'exec-followup' ||
            scenario == 'plain-then-tui' ||
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
    if (scenario == 'exec-bystander' && msg is KeyMsg && msg.key == 'q') {
      return (this, () => quit());
    }
    if (scenario == 'default-suspend' && msg is KeyMsg) {
      if (msg.key == 'ctrl+z') return (this, suspend);
      if (msg.key == 'q') return (this, () => quit());
    }
    if ((scenario == 'default-exec' ||
            scenario == 'default-exec-chain' ||
            scenario == 'explicit-exec') &&
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
      if (scenario == 'explicit-exec') stdout.writeln('EXPLICIT_EXEC_DONE');
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
              'plain-then-tui' => 'PLAIN_TUI_READY',
              'chain-one' => 'CHAIN_ONE_READY',
              'chain-two' => 'CHAIN_TWO_READY',
              'default-keys' => 'DEFAULT_KEYS_READY',
              'default-suspend' => 'DEFAULT_SUSPEND_READY',
              'default-term' => 'DEFAULT_TERM_READY',
              'default-exec' => 'DEFAULT_EXEC_READY',
              'default-exec-chain' => 'DEFAULT_EXEC_READY',
              'exec-bystander' => 'BYSTANDER',
              'default-init-exec' => 'DEFAULT_INIT_EXEC_READY',
              'default-init-exec-reads' => 'DEFAULT_INIT_EXEC_READY',
              'explicit-exec' => 'EXPLICIT_EXEC_READY',
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

final class _RestartReadyModel extends Model {
  @override
  Cmd? init() => () {
        stdout.writeln('SECOND_RUN_READY');
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) =>
      msg is KeyMsg && msg.key == 'q' ? (this, () => quit()) : (this, null);

  @override
  View view() => newView('Second run ready. Press q.');
}

Cmd _delayedQuit() => () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return QuitMsg();
    };
