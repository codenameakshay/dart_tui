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
