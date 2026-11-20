import 'package:__name__/__name__.dart';
import 'package:dart_tui/cli.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

void main() {
  late CaptureSink out;

  setUp(() => out = CaptureSink());

  // The output goes to a CaptureSink, so it has no colours.
  AppRunner app() => AppRunner(
        logger: Logger(stdout: out, environment: const {}),
        tick: Duration.zero,
      );

  test('help lists the commands under Basics', () {
    final help = app().usage;
    expect(help, contains('Basics:'));
    expect(help, contains('  count'));
    expect(help, contains('  greet'));
  });

  test('greet says hello', () async {
    expect(await app().run(['greet', 'Ada', '--shout']), 0);
    expect(out.text, 'HELLO, ADA!\n');
  });

  test('count ends with a summary', () async {
    expect(await app().run(['count', '--to', '2']), 0);
    expect(out.text, contains('Counted to 2'));
  });

  test('count rejects a bad number', () {
    expect(app().run(['count', '--to', 'x']), throwsA(isA<UsageException>()));
  });
}
