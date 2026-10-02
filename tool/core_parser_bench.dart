import 'dart:convert';

import 'package:dart_tui/src/input_decoder.dart';

void main() {
  const input = 'abcdefghé你🧑';
  final bytes = utf8.encode(input);
  final watch = Stopwatch()..start();
  var events = 0;
  for (var iteration = 0; iteration < 100000; iteration++) {
    events += TerminalInputDecoder().feed(bytes).length;
  }
  watch.stop();
  print('events=$events elapsed_us=${watch.elapsedMicroseconds}');
}
