// Asks three questions and prints a greeting.
//
//   dart run            questions in the terminal
//   dart run | cat      plain line questions, as in CI
import 'package:dart_tui/cli.dart';

Future<void> main() => greet(Logger());

/// Asks the questions with [logger], then prints the result.
Future<void> greet(Logger logger) async {
  final name =
      await logger.prompt('What is your name?', defaultValue: 'friend');
  final day = await logger.chooseOne(
    'How is your day?',
    choices: ['great', 'calm', 'busy'],
  );
  final shout = await logger.confirm('Shout it?');

  final greeting = 'Hello, $name! Have a $day day.';
  logger.success(shout ? greeting.toUpperCase() : greeting);
}
