import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('every rejects non-positive intervals immediately', () {
    expect(() => every(Duration.zero, (_) => QuitMsg()), throwsArgumentError);
    expect(
      () => every(const Duration(microseconds: -1), (_) => QuitMsg()),
      throwsArgumentError,
    );
  });

  test('tick helpers reject negative delays immediately', () {
    expect(() => tick(const Duration(microseconds: -1), (_) => QuitMsg()),
        throwsArgumentError);
    expect(
      () => tickWithId(const Duration(microseconds: -1), 'timer'),
      throwsArgumentError,
    );
  });

  test('timer validation errors show the rejected duration', () {
    final shown = throwsA(isA<ArgumentError>().having(
      (error) => '$error',
      'message',
      allOf(contains('-0:00:00.000001'), isNot(contains('Instance of'))),
    ));
    expect(
        () => every(const Duration(microseconds: -1), (_) => QuitMsg()), shown);
    expect(
        () => tick(const Duration(microseconds: -1), (_) => QuitMsg()), shown);
  });

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
