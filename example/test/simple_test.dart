// Run: dart test example/test
// Tests the countdown in example/simple.dart with package:dart_tui/testing.dart.

import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

import '../simple.dart';

void main() {
  test('the countdown starts at 5 and ticks down in real time', () async {
    final t = TuiTester(CountdownModel());
    addTearDown(t.dispose);
    expectScreen(t.screen, 'example/test/goldens/simple_start.txt');
    // No fake clock: the model's 1 s tick runs in real time.
    await t.waitFor((screen) => screen.startsWith('Ticks: 4'),
        timeout: const Duration(seconds: 3));
  });

  test('q quits', () async {
    final t = TuiTester(CountdownModel());
    addTearDown(t.dispose);
    await t.press('q');
    final result = await t.done();
    expect((result.model! as CountdownModel).count, 5);
  });
}
