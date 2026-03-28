import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/msg.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalInputDecoder lone Escape', () {
    test('takeLoneEscapeIfStillPending emits esc after lone 0x1b', () {
      final d = TerminalInputDecoder();
      expect(d.feed(const <int>[0x1b]), isEmpty);
      expect(d.hasPendingLoneEscape, isTrue);
      final msgs = d.takeLoneEscapeIfStillPending();
      expect(msgs, hasLength(1));
      expect(msgs.first, isA<KeyPressMsg>());
      expect((msgs.first as KeyPressMsg).key, 'esc');
      expect(d.hasPendingLoneEscape, isFalse);
    });

    test('split arrow sequence does not leave lone esc', () {
      final d = TerminalInputDecoder();
      expect(d.feed(const <int>[0x1b]), isEmpty);
      expect(d.hasPendingLoneEscape, isTrue);
      final rest = d.feed(const <int>[0x5b, 0x41]);
      expect(d.hasPendingLoneEscape, isFalse);
      expect(rest, hasLength(1));
      expect((rest.first as KeyPressMsg).key, 'up');
      expect(d.takeLoneEscapeIfStillPending(), isEmpty);
    });

    test('arrow in one chunk has no pending lone esc', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(const <int>[0x1b, 0x5b, 0x41]);
      expect(d.hasPendingLoneEscape, isFalse);
      expect(msgs, hasLength(1));
      expect((msgs.first as KeyPressMsg).key, 'up');
    });
  });
}
