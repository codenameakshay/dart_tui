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
final class _DriverModel extends TeaModel {
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
    await Program(programOptions: [
      withOutput(sink),
      withInput(null),
    ]).run(_DriverModel([
      SetWindowTitleMsg('safe\x07\x1b]2;owned\x07\x9c\x7fevil'),
    ]));

    final output = sink.buf.toString();
    expect(output, contains('\x1b]0;safe]2;ownedevil\x07'));
    expect(output, isNot(contains('\x1b]2;owned')));
  });

  test('kill wakes a program waiting without queued messages', () async {
    final ready = Completer<void>();
    final program = Program(programOptions: [
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
    final program = Program(programOptions: [
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

    await Program(programOptions: [
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

    await Program(programOptions: [
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
    await Program(programOptions: [
      withOutput(sink),
      withInput(null),
    ]).run(model).timeout(const Duration(seconds: 10));
    expect(model.exitCode, 0);
  }, timeout: const Timeout(Duration(seconds: 15)));
}

final class _IdleModel extends TeaModel {
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

final class _MouseCallbackModel extends TeaModel {
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

final class _ExecModel extends TeaModel {
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
