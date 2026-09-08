// ignore_for_file: avoid_print

import 'package:dart_tui/src/bubbles/canvas.dart';
import 'package:dart_tui/src/bubbles/text_area.dart';
import 'package:dart_tui/src/bubbles/text_input.dart';
import 'package:dart_tui/src/msg.dart';

void main() {
  final areaSamples = <int>[];
  final canvasSamples = <int>[];
  final inputSamples = <int>[];
  var checksum = 0;
  for (var sample = 0; sample < 6; sample++) {
    final (area, areaChecksum) = _textAreaRun();
    final (canvas, canvasChecksum) = _canvasRun();
    final (input, inputChecksum) = _textInputRun();
    checksum += areaChecksum + canvasChecksum + inputChecksum;
    if (sample > 0) {
      areaSamples.add(area.elapsedMicroseconds);
      canvasSamples.add(canvas.elapsedMicroseconds);
      inputSamples.add(input.elapsedMicroseconds);
    }
  }
  areaSamples.sort();
  canvasSamples.sort();
  inputSamples.sort();
  print(
      'text_area_update_view_us_median=${areaSamples[areaSamples.length ~/ 2]}');
  print(
      'canvas_clipped_long_line_us_median=${canvasSamples[canvasSamples.length ~/ 2]}');
  print(
      'text_input_navigation_view_us_median=${inputSamples[inputSamples.length ~/ 2]}');
  print('checksum=$checksum');
}

(Stopwatch, int) _textAreaRun() {
  final value = List.generate(40, (_) => '0123456789abcdef' * 3).join('\n');
  var model = TextAreaModel(value: value, width: 40, maxHeight: 12);
  var checksum = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < 300; i++) {
    model = model
        .update(
          KeyPressMsg(TeaKey(code: i.isEven ? KeyCode.down : KeyCode.up)),
        )
        .$1 as TextAreaModel;
    final view = model.view();
    checksum += view.content.length + (view.cursor?.x ?? 0);
  }
  watch.stop();
  if (model.visualLineCount == 0) throw StateError('empty text area');
  return (watch, checksum);
}

(Stopwatch, int) _canvasRun() {
  final canvas = Canvas(80, 4);
  canvas.paint(0, 0, '\x1b[31m${'x' * 50000}\x1b[0m');
  final watch = Stopwatch()..start();
  final output = canvas.render();
  watch.stop();
  if (output.length < 80) throw StateError('short canvas output');
  return (watch, output.length);
}

(Stopwatch, int) _textInputRun() {
  var model = TextInputModel(
    value: '0123456789abcdef' * 100,
    cursorPos: 800,
    suggestions: const ['prefix-one', 'prefix-two'],
  );
  var checksum = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < 1200; i++) {
    model = model
        .update(
          KeyPressMsg(TeaKey(code: i.isEven ? KeyCode.left : KeyCode.right)),
        )
        .$1 as TextInputModel;
    final view = model.view();
    checksum += view.content.length + (view.cursor?.x ?? 0);
  }
  watch.stop();
  if (model.value.isEmpty) throw StateError('empty text input');
  return (watch, checksum);
}
