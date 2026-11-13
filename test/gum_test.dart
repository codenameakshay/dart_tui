import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Drives [body] (a gum helper) with the test harness.
TuiTester _drive(Future<Object?> Function() body,
    {List<ProgramOption> options = const []}) {
  final t = TuiTester.run(body, width: 40, height: 10, options: options);
  addTearDown(t.dispose);
  return t;
}

void main() {
  group('filter', () {
    test('empty options returns null immediately', () async {
      expect(await filter(const []), isNull);
    });

    test('typing narrows and enter picks the match', () async {
      final t = _drive(() => filter(['apple', 'banana', 'apricot']));
      await t.type('b'); // only 'banana' matches
      await t.press('enter');
      expect((await t.done()).value, 'banana');
    });

    test('down moves the highlight before enter picks it', () async {
      final t = _drive(() => filter(['apple', 'apricot', 'banana']));
      await t.type('ap'); // apple, apricot
      await t.press('down');
      expectScreen(t.screen, 'test/goldens/gum_filter.txt');
      await t.press('enter');
      expect((await t.done()).value, 'apricot');
    });

    test('esc cancels', () async {
      final t = _drive(() => filter(['a', 'b']));
      await t.press('esc');
      expect((await t.done()).value, isNull);
    });
  });

  group('spin', () {
    test('animates while the task runs and returns its result', () async {
      final task = Completer<int>();
      // No fake clock: a short tick interval and waitFor follow real time.
      final t = _drive(() => spin(task.future, label: 'Working'),
          options: [withTickInterval(const Duration(milliseconds: 5))]);
      final first = t.screen;
      expectScreen(first, 'test/goldens/gum_spin.txt');
      await t.waitFor((screen) => screen != first);
      task.complete(42);
      expect((await t.done()).value, 42);
    });

    test('rethrows the task error', () async {
      final t = _drive(() => spin<int>(Future<int>.error(StateError('boom'))));
      await expectLater(t.done(), throwsStateError);
    });
  });

  group('pager', () {
    test('shows the content and exits on q', () async {
      final t = _drive(() => pager('line1\nline2\nline3', height: 5));
      expectScreen(t.screen, 'test/goldens/gum_pager.txt');
      await t.press('q');
      await t.done();
    });
  });
}
