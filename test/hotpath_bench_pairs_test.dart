import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:test/test.dart';
import 'package:dart_tui/testing.dart' show CaptureSink;

int _naiveVisibleWidth(String s) => s.characters.fold<int>(
      0,
      (w, g) => w + (g.runes.first > 0x7F ? 2 : 1),
    );

int _naiveAnsiWidth(String s) =>
    _naiveVisibleWidth(s.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), ''));

int _naiveDecoderChecksum(List<int> bytes) {
  var buf = <int>[...bytes];
  var checksum = 0;
  while (buf.isNotEmpty) {
    checksum += buf[0];
    buf.removeRange(0, 1);
  }
  return checksum;
}

int _dartTuiDecoderChecksum(List<int> bytes) {
  final decoder = TerminalInputDecoder();
  var checksum = 0;
  for (final msg in decoder.feed(bytes)) {
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
  return checksum;
}

void main() {
  test('naive ANSI width matches getWidth on SGR string', () {
    const s = '\x1b[31mabc\x1b[0m';
    expect(_naiveAnsiWidth(s), 3);
    expect(getWidth(s), 3);
  });

  test('CellRenderer second identical render does not grow sink', () {
    final buf = StringBuffer();
    final renderer = CellRenderer(
      output: CaptureSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );
    renderer.render(View(content: 'hello\nworld'));
    final afterFirst = buf.length;
    renderer.render(View(content: 'hello\nworld'));
    expect(buf.length, afterFirst);
  });

  test('naive and dart_tui decoders produce positive checksum for 1000 a bytes',
      () {
    final bytes = utf8.encode('a' * 1000);
    final naive = _naiveDecoderChecksum(bytes);
    final dartTui = _dartTuiDecoderChecksum(bytes);
    expect(naive, greaterThan(0));
    expect(dartTui, greaterThan(0));
  });

  test('reconstructing ViewportModel(yOffset: 1).view() is non-empty', () {
    final content = List.generate(10, (i) => 'line $i ${'x' * 80}').join('\n');
    final viewport = ViewportModel(
      content: content,
      width: 80,
      height: 24,
      yOffset: 1,
    );
    expect(viewport.view().content, isNotEmpty);
  });
}
