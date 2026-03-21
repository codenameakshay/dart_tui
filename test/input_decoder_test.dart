import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/msg.dart';
import 'package:test/test.dart';

void main() {
  test('decodes focus in/out', () {
    final d = TerminalInputDecoder();
    final msgs = d.feed([0x1b, 0x5b, 0x49, 0x1b, 0x5b, 0x4f]);
    expect(msgs.length, 2);
    expect(msgs[0], isA<FocusMsg>());
    expect(msgs[1], isA<BlurMsg>());
  });

  test('decodes bracketed paste across chunks', () {
    final d = TerminalInputDecoder();
    final start = d.feed([0x1b, 0x5b, 0x32]);
    expect(start, isEmpty);

    final part2 = d.feed([0x30, 0x30, 0x7e, 0x68, 0x69]);
    expect(part2.length, 1);
    expect(part2.first, isA<PasteStartMsg>());

    final part3 = d.feed([0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e]);
    expect(part3.length, 2);
    expect(part3[0], isA<PasteMsg>());
    expect((part3[0] as PasteMsg).content, 'hi');
    expect(part3[1], isA<PasteEndMsg>());
  });

  test('decodes regular keys when not in paste mode', () {
    final d = TerminalInputDecoder();
    final msgs = d.feed([0x61]);
    expect(msgs.length, 1);
    expect(msgs.first, isA<KeyPressMsg>());
    expect((msgs.first as KeyPressMsg).key, 'a');
  });
}
