import 'package:dart_tui/cli.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

import '../bin/__name__.dart';

void main() {
  test('greet asks three questions and prints the greeting', () async {
    final out = CaptureSink();
    final logger = Logger(stdout: out, environment: const {});
    // TuiTester drives each prompt as a real program, without a terminal.
    final t = TuiTester.run(() => greet(logger));
    addTearDown(t.dispose);

    await t.waitFor((screen) => screen.contains('What is your name?'));
    await t.type('Ada');
    await t.press('enter');
    await t.waitFor((screen) => screen.contains('How is your day?'));
    await t.press('down');
    await t.press('enter');
    await t.waitFor((screen) => screen.contains('Shout it?'));
    await t.press('y');
    await t.done();

    expect(out.text, contains('HELLO, ADA! HAVE A CALM DAY.'));
  });
}
