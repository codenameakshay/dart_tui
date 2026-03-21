import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('batch wraps multiple commands in BatchMsg', () async {
    final c = batch([
      () async => KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'a')),
      () async => KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'b')),
    ])!;
    final m = await c();
    expect(m, isA<BatchMsg>());
    final batchMsg = m! as BatchMsg;
    expect(batchMsg.cmds.length, 2);
  });

  test('sequence wraps multiple commands in SequenceMsg', () async {
    final c = sequence([
      () async => KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'x')),
      () async => KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'y')),
    ])!;
    final m = await c();
    expect(m, isA<SequenceMsg>());
    final seq = m! as SequenceMsg;
    expect(seq.cmds.length, 2);
  });
}
