import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('batch combines messages', () async {
    final c = batch([
      () async => KeyMsg('a'),
      () async => KeyMsg('b'),
    ]);
    final m = await c();
    expect(m, isA<CompoundMsg>());
    final compound = m! as CompoundMsg;
    expect(compound.msgs.length, 2);
  });

  test('sequence returns first non-null', () async {
    final c = sequence([
      () async => null,
      () async => KeyMsg('x'),
    ]);
    final m = await c();
    expect(m, isA<KeyMsg>());
    expect((m! as KeyMsg).key, 'x');
  });
}
