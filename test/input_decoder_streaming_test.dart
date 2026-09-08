import 'dart:convert';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:test/test.dart';

void main() {
  test('long fragmented string sequences resume scanning at the last byte', () {
    final decoder = TerminalInputDecoder();
    final data = utf8.encode('\x1b]99;${'x' * 10000}\x07a');
    final messages = <Msg>[];

    for (final byte in data) {
      messages.addAll(decoder.feed([byte]));
    }

    expect(messages, hasLength(1));
    expect((messages.single as KeyPressMsg).keyEvent.text, 'a');
  });

  test('long fragmented capability responses resume DCS scanning', () {
    final decoder = TerminalInputDecoder();
    final data = utf8.encode('\x1bP+r${'61' * 5000}\x1b\\a');
    final messages = <Msg>[];

    for (final byte in data) {
      messages.addAll(decoder.feed([byte]));
    }

    expect(messages, hasLength(2));
    expect(messages.first, isA<CapabilityMsg>());
    expect((messages.last as KeyPressMsg).keyEvent.text, 'a');
  });

  test('long fragmented CSI responses resume scanning', () {
    final decoder = TerminalInputDecoder();
    final data = utf8.encode('\x1b[${'1;' * 5000}za');
    final messages = <Msg>[];

    for (final byte in data) {
      messages.addAll(decoder.feed([byte]));
    }

    expect(messages, hasLength(1));
    expect((messages.single as KeyPressMsg).keyEvent.text, 'a');
  });

  test('compaction keeps a partial sequence after consumed input', () {
    final decoder = TerminalInputDecoder();
    final prefix = utf8.encode('a' * 5000);
    final partial = utf8.encode('\x1b]99;${'x' * 10000}');
    final messages = <Msg>[];
    messages.addAll(decoder.feed([...prefix, ...partial]));
    messages.addAll(decoder.feed([0x07, 0x61]));

    expect(messages.length, greaterThan(1));
    expect((messages.last as KeyPressMsg).keyEvent.text, 'a');
  });

  test('fragmented bracketed paste preserves Unicode text', () {
    final decoder = TerminalInputDecoder();
    final data = utf8.encode('\x1b[200~नमस्ते🙂\x1b[201~');
    final messages = <Msg>[];

    for (final byte in data) {
      messages.addAll(decoder.feed([byte]));
    }

    expect(messages.whereType<PasteMsg>().single.content, 'नमस्ते🙂');
    expect(messages.whereType<PasteStartMsg>(), hasLength(1));
    expect(messages.whereType<PasteEndMsg>(), hasLength(1));
  });
}
