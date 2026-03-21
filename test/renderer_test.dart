import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

void main() {
  test('renderer skips identical frame content', () async {
    final chunks = <String>[];
    final controller = StreamController<List<int>>();
    controller.stream.listen((data) => chunks.add(utf8.decode(data)));
    final sink = IOSink(controller.sink);

    final r = AnsiRenderer(
      output: sink,
      defaultAltScreen: false,
      defaultHideCursor: true,
    );

    r.render(newView('hello'));
    await sink.flush();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final first = chunks.join();
    expect(first, contains('hello'));

    chunks.clear();
    r.render(newView('hello'));
    await sink.flush();
    expect(chunks.join(), isEmpty);

    r.close();
    await sink.close();
    await controller.close();
  });
}
