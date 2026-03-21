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
      options: const ProgramOptions(altScreen: false),
      programOptions: [withInput(null), withOutput(sink)],
    );

    await program.run(_RequestModel());
    await sink.flush();
    final out = chunks.join();
    expect(out, contains('\x1b]10;?\x07'));
    expect(out, contains('\x1b[6n'));

    await sink.close();
    await controller.close();
  });
}

final class _RequestModel extends TeaModel {
  @override
  Cmd? init() {
    return sequence([
      () => requestForegroundColor(),
      () => requestCursorPosition(),
      () => quit(),
    ]);
  }

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}
