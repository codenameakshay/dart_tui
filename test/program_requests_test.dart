import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('program emits terminal request sequences', () async {
    final chunks = <String>[];
    final controller = StreamController<List<int>>();
    controller.stream.listen((data) => chunks.add(utf8.decode(data)));
    final sink = IOSink(controller.sink);

    final program = Program(
      options: [
        withInput(const Stream<List<int>>.empty()),
        withOutput(sink),
      ],
    );

    await program.run(_RequestModel());
    await sink.flush();
    final out = chunks.join();
    expect(out, contains('\x1b]10;?\x07'));
    expect(out, contains('\x1b[6n'));
    expect(out, contains('\x1b[?2026\$p'));
    expect(out, contains('\x1b[?2027\$p'));

    await sink.close();
    await controller.close();
  });

  test('program with tickInterval exits cleanly after quit', () async {
    final program = Program(
      options: [
        withInput(null),
        withTickInterval(const Duration(milliseconds: 10)),
      ],
    );

    await program.run(_ImmediateQuitModel());
  });

  test('a killed startup reply wait cannot pause its replacement input',
      () async {
    if (Platform.isWindows) return;
    final firstInput = StreamController<List<int>>();
    final replacementInput = StreamController<List<int>>();
    final output = StreamController<List<int>>();
    final outputDone = output.stream.drain<void>();
    final sink = IOSink(output.sink);
    final execEntered = Completer<void>();
    final replacementReady = Completer<void>();
    final replacementKeys = <String>[];
    final program = Program(options: [
      withInput(firstInput.stream),
      withOutput(sink),
      withoutRenderer(),
      withoutSignalHandler(),
      withFilter((_, msg) {
        if (msg is ExecMsg && !execEntered.isCompleted) execEntered.complete();
        return msg;
      }),
    ]);
    Future<Object?>? replacementRun;
    try {
      final firstRun = program.run(_StartupExecModel());
      await execEntered.future;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      program.kill();
      withInput(replacementInput.stream)(program);
      replacementRun = program.run(
        _InputReadyModel(replacementReady, replacementKeys),
      );
      await replacementReady.future;
      await firstRun;
      replacementInput.add(utf8.encode('q'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(replacementKeys, ['q']);
    } finally {
      program.kill();
      await replacementRun;
      await firstInput.close();
      await replacementInput.close();
      await sink.close();
      await outputDone;
    }
  });

  test('an inherited exec with input disabled sends no startup queries',
      () async {
    if (Platform.isWindows) return;
    final chunks = <int>[];
    final output = StreamController<List<int>>();
    final outputDone = output.stream.forEach(chunks.addAll);
    final sink = IOSink(output.sink);
    final exits = <int>[];
    final program = Program(options: [
      withInput(null),
      withOutput(sink),
      withoutRenderer(),
      withoutSignalHandler(),
    ]);
    try {
      await program.run(_StartupExecModel(exits: exits)).timeout(
            const Duration(seconds: 1),
          );
      await sink.flush();
      expect(exits, [0]);
      expect(utf8.decode(chunks), isNot(contains('\x1b[?2026\$p')));
      expect(utf8.decode(chunks), isNot(contains('\x1b]11;?\x07')));
    } finally {
      program.kill();
      await sink.close();
      await outputDone;
    }
  });

  test('a custom input stream drains startup replies before inherited exec',
      () async {
    if (Platform.isWindows) return;
    final input = StreamController<List<int>>();
    final output = StreamController<List<int>>();
    final outputDone = output.stream.drain<void>();
    final sink = IOSink(output.sink);
    final execEntered = Completer<void>();
    final exits = <int>[];
    final replies = <String>[];
    final program = Program(options: [
      withInput(input.stream),
      withOutput(sink),
      withoutRenderer(),
      withoutSignalHandler(),
      withFilter((_, msg) {
        if (msg is ExecMsg) execEntered.complete();
        return msg;
      }),
    ]);
    final run = program.run(_StartupExecModel(exits: exits, replies: replies));
    try {
      await execEntered.future;
      input.add(utf8.encode('\x1b[?2026;2\$y\x1b[?2027;0\$y'));
      input.add(utf8.encode('\x1b]11;rgb:0000/0000/0000\x07'));
      await run.timeout(const Duration(seconds: 1));
      expect(exits, [0]);
      expect(replies, ['mode:2026', 'mode:2027', 'background:0']);
    } finally {
      program.kill();
      await run;
      await input.close();
      await sink.close();
      await outputDone;
    }
  });
}

final class _StartupExecModel extends Model {
  _StartupExecModel({this.exits, this.replies});

  final List<int>? exits;
  final List<String>? replies;

  @override
  Cmd? init() => execProcess('/bin/sh', ['-c', 'exit 0'], onExit: (code) {
        exits?.add(code);
        return quit();
      });

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ModeReportMsg) replies?.add('mode:${msg.mode}');
    if (msg is BackgroundColorMsg) replies?.add('background:${msg.rgb}');
    return (this, null);
  }

  @override
  View view() => newView('');
}

final class _InputReadyModel extends Model {
  _InputReadyModel(this.ready, this.keys);

  final Completer<void> ready;
  final List<String> keys;

  @override
  Cmd? init() => () {
        ready.complete();
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      keys.add(msg.key);
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView('');
}

final class _RequestModel extends Model {
  @override
  Cmd? init() {
    return sequence([
      () => requestForegroundColor(),
      () => requestCursorPosition(),
      () => quit(),
    ]);
  }

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}

final class _ImmediateQuitModel extends Model {
  @override
  Cmd? init() => () => quit();

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}
