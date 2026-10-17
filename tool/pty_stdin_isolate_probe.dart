import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_tui/dart_tui.dart';

Future<void> main(List<String> arguments) async {
  final scenario = arguments.isEmpty ? null : arguments.single;
  if (scenario == 'concurrent') {
    await _runConcurrentPrograms();
    return;
  }
  if (scenario == 'eof') {
    await _runAfterEof();
    return;
  }
  if (scenario == 'term') {
    await _runSignalLifecycle();
    return;
  }
  if (scenario == 'inherited-pipe') {
    await _runInheritedPipe();
    return;
  }
  if (scenario == 'inherited-overlap-kill' ||
      scenario == 'inherited-overlap-quit') {
    await _runInheritedPipe(interruption: scenario!.split('-').last);
    return;
  }
  if (scenario == 'inherited-wait-child') {
    final stopped = ProcessSignal.sigterm.watch();
    final stop = stopped.first;
    stdout.writeln('PIPE_WAIT_CHILD:$pid');
    await stop;
    return;
  }
  if (scenario == 'inherited-pipe-child') {
    stdout.writeln('PIPE_CHILD_READY');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    stdout.writeln('PIPE_CHILD_GOT:${stdin.readLineSync()}');
    return;
  }

  await _runOtherIsolates();
}

Future<void> _runInheritedPipe({String? interruption}) async {
  final executor = Program(options: [withoutRenderer(), withInput(null)]);
  final reader = Program(options: [withoutRenderer()]);
  void startExec() {
    executor.send(ExecMsg(
      cmd: Platform.resolvedExecutable,
      args: ['run', Platform.script.toFilePath(), 'inherited-pipe-child'],
      onExit: (code) {
        stdout.writeln('PIPE_EXEC_DONE:$code');
        return QuitMsg();
      },
    ));
  }

  final firstExecutor = Program(options: [withoutRenderer(), withInput(null)]);
  var signals = 0;
  final control = interruption == null
      ? null
      : ProcessSignal.sigusr1.watch().listen((_) {
          if (++signals == 1) {
            startExec();
          } else {
            if (interruption == 'kill') {
              firstExecutor.kill();
            } else {
              firstExecutor.quit();
            }
            stdout.writeln('PIPE_A_REQUESTED:$interruption');
          }
        });
  try {
    await Future.wait([
      executor.run(_QuitOnKey(() {})),
      reader.run(_InheritedPipeReader(startExec)),
      if (interruption != null)
        firstExecutor.run(_WaitChild()).then((_) {
          stdout.writeln('PIPE_A_DONE');
        }),
    ]);
  } finally {
    await control?.cancel();
  }
  stdout.writeln('PIPE_DONE');
}

final class _WaitChild extends Model {
  @override
  Cmd? init() => execProcess(
        Platform.resolvedExecutable,
        ['run', Platform.script.toFilePath(), 'inherited-wait-child'],
        onExit: (_) => QuitMsg(),
      );

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}

final class _InheritedPipeReader extends Model {
  _InheritedPipeReader(this.startExec);
  final void Function() startExec;

  @override
  Cmd? init() => () {
        stdout.writeln('PIPE_READY');
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    if (msg.key == 's') startExec();
    if (msg.key == 'q') return (this, () => QuitMsg());
    if (msg.key != 's') stdout.writeln('PIPE_READER_KEY:${msg.key}');
    return (this, null);
  }

  @override
  View view() => newView('');
}

Future<void> _runOtherIsolates() async {
  stdout.writeln('ROOT_ISOLATE:${Isolate.current.debugName}');
  // Only the main isolate reads default stdin; other isolates must say where
  // their input comes from.
  final refused = await Isolate.run(() async {
    try {
      await Program(options: [withoutRenderer()]).run(_QuitImmediately());
      return 'ran';
    } on StateError catch (error) {
      return 'refused ${error.message}';
    }
  });
  stdout.writeln('CHILD_DEFAULT:$refused');
  final explicit = await Isolate.run(() async {
    await Program(options: [withoutRenderer(), withInput(null)])
        .run(_QuitImmediately());
    await Program(options: [
      withoutRenderer(),
      withInput(Stream<List<int>>.value([113])),
    ]).run(_QuitOnKey(() {}));
    return 'ok';
  });
  stdout.writeln('CHILD_EXPLICIT:$explicit');
  await Program(options: [withoutRenderer()]).run(_QuitOnKey(
    () => stdout.writeln('MAIN_READY'),
  ));
  stdout.writeln('MAIN_DONE');
}

Future<void> _runConcurrentPrograms() async {
  var readyPrograms = 0;
  void ready() {
    readyPrograms++;
    if (readyPrograms == 2) stdout.writeln('CONCURRENT_READY');
  }

  await Future.wait([
    Program(options: [withoutRenderer()]).run(_QuitOnKey(ready)),
    Program(options: [withoutRenderer()]).run(_QuitOnKey(ready)),
  ]);
  stdout.writeln('CONCURRENT_DONE');
}

Future<void> _runAfterEof() async {
  await Program(options: [withoutRenderer()]).run(_QuitOnKey(
    () => stdout.writeln('EOF_READY'),
  ));
  stdout.writeln('EOF_FIRST_DONE');
  await Program(options: [withoutRenderer()]).run(_QuitImmediately());
  stdout.writeln('EOF_CHAIN_DONE');
}

Future<void> _runSignalLifecycle() async {
  var vetoFirstQuit = true;
  final program = Program(options: [
    withoutRenderer(),
    withFilter((_, msg) {
      if (msg is QuitMsg && vetoFirstQuit) {
        vetoFirstQuit = false;
        stdout.writeln('TERM_VETOED');
        return null;
      }
      return msg;
    }),
  ]);
  await program.run(_SignalReadyModel());
  stdout.writeln('TERM_PROGRAM_DONE');
  Timer.periodic(const Duration(days: 1), (_) {});
  stdout.writeln('TERM_AFTER_READY');
}

final class _QuitImmediately extends Model {
  @override
  Cmd? init() => () => QuitMsg();

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}

final class _QuitOnKey extends Model {
  _QuitOnKey(this.onReady);
  final void Function() onReady;

  @override
  Cmd? init() => () {
        onReady();
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) =>
      msg is KeyMsg && msg.key == 'q' ? (this, () => QuitMsg()) : (this, null);

  @override
  View view() => newView('');
}

final class _SignalReadyModel extends Model {
  @override
  Cmd? init() => () {
        stdout.writeln('TERM_READY');
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}
