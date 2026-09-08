import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/bubbles/style.dart';
import 'package:dart_tui/src/ansi_state.dart';
import 'package:dart_tui/src/msg.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';

final class _Sink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> close() async {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
  @override
  void write(Object? object) => buffer.write(object);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
}

void main() {
  final plain = List.filled(20, 'hello world ').join();
  final ansi = '\x1b[31m$plain\x1b[0m';
  final longStyled = List.generate(
    2500,
    (i) => '\x1b[38;5;${i % 256}mitem$i\x1b[0m',
  ).join();
  final style = const Style(
    foregroundRgb: RgbColor(123, 45, 231),
    profile: ColorProfile.ansi256,
  );
  final frame = View(content: ansi);

  assert(getWidth('👩\x1b[31m\u200d💻') == 2);
  assert(getWidth('🇮\x1b[31m🇳') == 2);

  _measure('getWidth plain', () {
    var result = 0;
    for (var i = 0; i < 10000; i++) {
      result += getWidth(plain);
    }
    if (result == 0) throw StateError('unreachable');
  });
  _measure('getWidth ansi', () {
    var result = 0;
    for (var i = 0; i < 10000; i++) {
      result += getWidth(ansi);
    }
    if (result == 0) throw StateError('unreachable');
  });
  _measure('style ansi256', () {
    var result = 0;
    for (var i = 0; i < 10000; i++) {
      result += style.render(plain).length;
    }
    if (result == 0) throw StateError('unreachable');
  });
  _measure(
    'tokenize 50k styled ANSI',
    () {
      final tokens = tokenizeAnsi(longStyled);
      if (tokens.isEmpty) throw StateError('tokenizer emitted no tokens');
    },
    sampleCount: 3,
  );
  _measure('cell 1000 alternating frames', () {
    final sink = _Sink();
    final renderer = CellRenderer(
      output: sink,
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    final changed = View(content: ansi.replaceFirst('hello', 'jello'));
    for (var i = 0; i < 1000; i++) {
      renderer.render(i.isEven ? frame : changed);
    }
    if (sink.buffer.isEmpty) throw StateError('renderer emitted no output');
  });
  _measure('cell 1000 identical frames', () {
    final sink = _Sink();
    final renderer = CellRenderer(
      output: sink,
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.render(frame);
    for (var i = 0; i < 1000; i++) {
      renderer.render(frame);
    }
    if (sink.buffer.isEmpty) throw StateError('renderer emitted no output');
  });
}

void _measure(String name, void Function() action, {int sampleCount = 5}) {
  action();
  final timings = <int>[];
  for (var i = 0; i < sampleCount; i++) {
    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
  }
  timings.sort();
  print('$name: ${timings[timings.length ~/ 2]} us (median of $sampleCount)');
}
