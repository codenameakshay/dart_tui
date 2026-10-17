import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

class _StringSink implements IOSink {
  final StringBuffer buf = StringBuffer();
  @override
  void write(Object? obj) => buf.write(obj);
  @override
  void writeln([Object? obj = '']) => buf.writeln(obj);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buf.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => buf.writeCharCode(charCode);
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  void add(List<int> data) => buf.write(utf8.decode(data));
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
}

/// Runs [msgs] in order through a real Program + AnsiRenderer, then quits.
final class _DriverModel extends Model {
  _DriverModel(this.msgs);
  final List<Msg> msgs;

  @override
  Cmd? init() => sequence([
        ...msgs.map((m) => () => m),
        () => QuitMsg(),
      ]);

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('driver');
}

void main() {
  test('SetWindowTitleMsg strips OSC control characters', () async {
    final sink = _StringSink();
    await Program(options: [
      withOutput(sink),
      withInput(null),
    ]).run(_DriverModel([
      SetWindowTitleMsg('safe\x07\x1b]2;owned\x07\x9c\x7fevil'),
    ]));

    final output = sink.buf.toString();
    expect(output, contains('\x1b]0;safe]2;ownedevil\x07'));
    expect(output, isNot(contains('\x1b]2;owned')));
  });

  test('the frame for the update before quit is rendered', () async {
    final sink = _StringSink();
    final ready = Completer<void>();
    final program = Program(options: [withOutput(sink), withInput(null)]);
    final run = program.run(_ReadyModel(ready));
    await ready.future;
    program
      ..send(_LabelMsg('final'))
      ..send(QuitMsg());
    await run;
    expect(sink.buf.toString(), contains('label=final'));
  });

  test('a running sequence does not block other messages', () async {
    final log = <String>[];
    final ready = Completer<void>();
    final program =
        Program(options: [withOutput(_StringSink()), withInput(null)]);
    final run = program.run(_ReadyModel(ready, log: log));
    await ready.future;
    program.send(SequenceMsg([
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return _LabelMsg('slow');
      },
      () => _LabelMsg('after-slow'),
    ]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    program.send(_LabelMsg('key'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(log, ['key']);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    program.quit();
    await run;
    expect(log, ['key', 'slow', 'after-slow']);
  });

  test('a command failure stops the remaining sequence', () async {
    final ready = Completer<void>();
    var laterCommandRan = false;
    final program =
        Program(options: [withOutput(_StringSink()), withInput(null)]);
    final run = program.run(_ReadyModel(ready));
    await ready.future;
    program.send(SequenceMsg([
      () => throw StateError('sequence failed'),
      () {
        laterCommandRan = true;
        return _LabelMsg('must-not-run');
      },
    ]));
    await run;
    expect(laterCommandRan, isFalse);
  });

  test('a quit result stops the remaining sequence', () async {
    final ready = Completer<void>();
    var laterCommandRan = false;
    final program =
        Program(options: [withOutput(_StringSink()), withInput(null)]);
    final run = program.run(_ReadyModel(ready));
    await ready.future;
    program.send(SequenceMsg([
      () => QuitMsg(),
      () {
        laterCommandRan = true;
        return _LabelMsg('after-quit');
      },
    ]));
    await run;
    expect(laterCommandRan, isFalse);
  });

  test('an old sequence cannot continue into a later run', () async {
    final firstReady = Completer<void>();
    final secondReady = Completer<void>();
    final firstStep = Completer<Msg?>();
    final log = <String>[];
    var laterCommandRan = false;
    final program =
        Program(options: [withOutput(_StringSink()), withInput(null)]);
    final firstRun = program.run(_ReadyModel(firstReady, log: log));
    await firstReady.future;
    program.send(SequenceMsg([
      () => firstStep.future,
      () {
        laterCommandRan = true;
        return null;
      },
    ]));
    await Future<void>.delayed(Duration.zero);
    program.quit();
    await firstRun;

    final secondRun = program.run(_ReadyModel(secondReady, log: log));
    await secondReady.future;
    firstStep.complete(_LabelMsg('stale'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    program.quit();
    await secondRun;

    expect(laterCommandRan, isFalse);
    expect(log, isNot(contains('stale')));
  });

  test('leaving the alt screen does not print a blank line', () async {
    Future<String> runWith(List<ProgramOption> options) async {
      final sink = _StringSink();
      await Program(options: [withOutput(sink), withInput(null), ...options])
          .run(_DriverModel(const []));
      return sink.buf.toString();
    }

    expect(await runWith([withAltScreen()]), isNot(endsWith('\n')));
    expect(await runWith(const []), endsWith('\n'));
  });

  test('kill wakes a program waiting without queued messages', () async {
    final ready = Completer<void>();
    final program = Program(options: [
      withInput(null),
      withoutRenderer(),
    ]);
    final runFuture = program.run(_IdleModel(ready));
    await ready.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    program.kill();

    await runFuture.timeout(const Duration(milliseconds: 200));
  });

  test('last rendered view handles mouse events through the command queue',
      () async {
    final ready = Completer<void>();
    final handled = Completer<Mouse>();
    final program = Program(options: [
      withOutput(_StringSink()),
      withInput(null),
    ]);
    final runFuture = program.run(_MouseCallbackModel(ready, handled));
    addTearDown(() async {
      program.kill();
      await runFuture;
    });
    await ready.future.timeout(const Duration(seconds: 1));

    program.send(MouseClickMsg(const Mouse(
      x: 7,
      y: 3,
      button: MouseButton.left,
    )));

    final mouse =
        await handled.future.timeout(const Duration(milliseconds: 300));
    expect((mouse.x, mouse.y, mouse.button), (7, 3, MouseButton.left));
    await runFuture.timeout(const Duration(seconds: 1));
  });

  test('applyMsg drives the terminal-control switch + renderer methods',
      () async {
    final sink = _StringSink();
    final controls = <Msg>[
      RequestWindowSizeMsg(),
      RequestForegroundColorMsg(),
      RequestBackgroundColorMsg(),
      RequestCursorColorMsg(),
      RequestCursorPositionMsg(),
      RequestTerminalVersionMsg(),
      RequestCapabilityMsg('Smulx'),
      SetClipboardMsg('hi'),
      ReadClipboardMsg(),
      SetPrimaryClipboardMsg('yo'),
      ReadPrimaryClipboardMsg(),
      EnterAltScreenMsg(),
      ExitAltScreenMsg(),
      HideCursorMsg(),
      ShowCursorMsg(),
      SetWindowTitleMsg('T'),
      ClearScrollAreaMsg(),
      ScrollMsg(2, up: true),
      ScrollMsg(1, up: false),
      ClearScreenMsg(),
      PrintLineMsg('above'),
    ];

    await Program(options: [
      withOutput(sink),
      withInput(null),
    ]).run(_DriverModel(controls)).timeout(const Duration(seconds: 5));

    final out = sink.buf.toString();
    expect(out, contains('\x1b]0;T\x07')); // window title
    expect(out, contains('\x1b[?1049h')); // enter alt-screen
    expect(out, contains('\x1b[2S')); // scroll up 2
    expect(out, contains('\x1b]52;c;')); // clipboard OSC 52
    expect(out, contains('above')); // printLine
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('Unicode Core support enables mode 2027 and resets it at shutdown',
      () async {
    final sink = _StringSink();

    await Program(options: [
      withOutput(sink),
      withInput(null),
    ]).run(_DriverModel([
      ModeReportMsg(mode: 2027, value: 3),
    ]));

    final output = sink.buf.toString();
    expect(output, contains('\x1b[?2027h'));
    expect(output, contains('\x1b[?2027l'));
  });

  test('ExecMsg runs a subprocess and fires onExit', () async {
    final sink = _StringSink();
    // A model whose init execs `true` (exit 0), then quits on the callback.
    final model = _ExecModel();
    await Program(options: [
      withOutput(sink),
      withInput(null),
    ]).run(model).timeout(const Duration(seconds: 10));
    expect(model.exitCode, 0);
  }, timeout: const Timeout(Duration(seconds: 15)));
}

final class _ReadyModel extends Model {
  _ReadyModel(this.ready, {this.label = 'start', this.log});
  final Completer<void> ready;
  final String label;
  final List<String>? log;

  @override
  Cmd? init() => () {
        if (!ready.isCompleted) ready.complete();
        return null;
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _LabelMsg) {
      log?.add(msg.label);
      return (_ReadyModel(ready, label: msg.label, log: log), null);
    }
    return (this, null);
  }

  @override
  View view() => newView('label=$label');
}

final class _LabelMsg extends Msg {
  _LabelMsg(this.label);
  final String label;
}

final class _IdleModel extends Model {
  _IdleModel(this.ready);

  final Completer<void> ready;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is EnvMsg && !ready.isCompleted) ready.complete();
    return (this, null);
  }

  @override
  View view() => newView('idle');
}

final class _MouseHandledMsg extends Msg {
  _MouseHandledMsg(this.mouse);

  final Mouse mouse;
}

final class _MouseCallbackModel extends Model {
  _MouseCallbackModel(this.ready, this.handled);

  final Completer<void> ready;
  final Completer<Mouse> handled;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is EnvMsg && !ready.isCompleted) ready.complete();
    if (msg case _MouseHandledMsg(:final mouse)) {
      if (!handled.isCompleted) handled.complete(mouse);
      return (this, () => QuitMsg());
    }
    return (this, null);
  }

  @override
  View view() => View(
        content: 'mouse callback',
        mouseMode: MouseMode.cellMotion,
        onMouse: (msg) => () => _MouseHandledMsg(msg.mouse),
      );
}

final class _ExecModel extends Model {
  int? exitCode;

  @override
  Cmd? init() => execProcess(
        Platform.isWindows ? 'cmd' : 'true',
        Platform.isWindows ? ['/c', 'exit', '0'] : const [],
        inheritStdio: false,
        onExit: (code) {
          exitCode = code;
          return QuitMsg();
        },
      );

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('exec');
}
