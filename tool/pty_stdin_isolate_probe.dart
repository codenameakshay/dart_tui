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

  await _runOtherIsolates();
}

Future<void> _runOtherIsolates() async {
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
