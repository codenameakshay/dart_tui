// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';

typedef _BenchCase = ({String name, List<int> bytes, int chunkSize});

void main() {
  final cases = <_BenchCase>[
    (
      name: 'plain buffer',
      bytes: utf8.encode('a' * 100000),
      chunkSize: 100000,
    ),
    (
      name: 'bracketed paste',
      bytes: utf8.encode('\x1b[200~${'🙂' * 25000}\x1b[201~'),
      chunkSize: 4096,
    ),
    (
      name: 'fragmented OSC',
      bytes: utf8.encode('\x1b]99;${'x' * 50000}\x07a'),
      chunkSize: 1,
    ),
    (
      name: 'fragmented DCS',
      bytes: utf8.encode('\x1bP+r${'61' * 25000}\x1b\\a'),
      chunkSize: 1,
    ),
    (
      name: 'fragmented CSI',
      bytes: utf8.encode('\x1b[${'1;' * 25000}za'),
      chunkSize: 1,
    ),
  ];

  for (final testCase in cases) {
    final samples = <int>[];
    var checksum = 0;
    for (var run = 0; run < 6; run++) {
      final watch = Stopwatch()..start();
      checksum = _decode(testCase.bytes, testCase.chunkSize);
      watch.stop();
      if (run > 0) samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    print(
      '${testCase.name}: median ${median / 1000.0} ms '
      '(${testCase.bytes.length} bytes, checksum $checksum)',
    );
  }
}

int _decode(List<int> bytes, int chunkSize) {
  final decoder = TerminalInputDecoder();
  var checksum = 0;
  for (var start = 0; start < bytes.length; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, bytes.length);
    for (final msg in decoder.feed(bytes.sublist(start, end))) {
      checksum += switch (msg) {
        KeyPressMsg(:final keyEvent) => keyEvent.text.length + 1,
        KeyReleaseMsg(:final keyEvent) => keyEvent.text.length + 2,
        PasteMsg(:final content) => content.length + 3,
        PasteStartMsg() => 4,
        PasteEndMsg() => 5,
        CapabilityMsg(:final content) => content.length + 6,
        _ => 7,
      };
    }
  }
  return checksum;
}
