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
