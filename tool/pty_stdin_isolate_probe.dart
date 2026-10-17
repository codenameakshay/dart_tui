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
  if (scenario == 'isolate-then-main') {
    await _runIsolateThenMain();
    return;
  }

  final completed = ReceivePort();
  final events = StreamIterator<Object?>(completed);
  for (var i = 0; i < 32; i++) {
    await Isolate.spawn(_runAndQuit, completed.sendPort);
    await events.moveNext();
  }
  await events.cancel();
  completed.close();
  print('ISOLATE_PROGRAMS_DONE');
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

Future<void> _runIsolateThenMain() async {
  // A program in a short-lived isolate must not take stdin away from a later
  // program in this isolate.
  final completed = ReceivePort();
  await Isolate.spawn(_runAndQuit, completed.sendPort);
  await completed.first;
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await Program(options: [withoutRenderer()]).run(_QuitOnKey(
    () => stdout.writeln('MAIN_READY'),
  ));
  stdout.writeln('MAIN_DONE');
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

Future<void> _runAndQuit(SendPort completed) async {
  await Program(options: [withoutRenderer()]).run(_QuitImmediately());
  completed.send(null);
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
