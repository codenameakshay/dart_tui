import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

Stream<List<int>> _seq(List<List<int>> chunks) => Stream.fromIterable(chunks);
List<ProgramOption> _opts(List<List<int>> chunks) =>
    [withoutRenderer(), withInput(_seq(chunks))];

const _enter = [0x0d];
const _esc = [0x1b];
const _timeout = Timeout(Duration(seconds: 5));

void main() {
  group('filter', () {
    test('empty options returns null immediately', () async {
      expect(await filter(const []), isNull);
    });

    test('typing narrows and enter picks the match', () async {
      final r = await filter(
        ['apple', 'banana', 'apricot'],
        options: _opts([
          [0x62], // 'b' → only 'banana' matches
          _enter,
        ]),
      );
      expect(r, 'banana');
    }, timeout: _timeout);

    test('esc cancels', () async {
      // esc is a lone escape: the program schedules a short timer to deliver it.
      final r = await filter(['a', 'b'], options: _opts([_esc]));
      expect(r, isNull);
    }, timeout: _timeout);
  });

  group('spin', () {
    test('returns the task result', () async {
      final r = await spin(
        Future<int>.value(42),
        options: [withoutRenderer(), withInput(null)],
      );
      expect(r, 42);
    }, timeout: _timeout);

    test('rethrows the task error', () async {
      await expectLater(
        spin<int>(
          Future<int>.error(StateError('boom')),
          options: [withoutRenderer(), withInput(null)],
        ),
        throwsA(isA<StateError>()),
      );
    }, timeout: _timeout);
  });

  group('pager', () {
    test('exits on q', () async {
      await pager(
        'line1\nline2\nline3',
        options: _opts([
          [0x71], // 'q'
        ]),
      );
      expect(true, isTrue); // completed without hanging
    }, timeout: _timeout);
  });
}
