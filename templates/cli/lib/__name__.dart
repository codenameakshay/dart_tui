/// The `__name__` command and its subcommands.
library;

import 'package:dart_tui/cli.dart';

/// The app: `__name__ <command> [arguments]`.
///
/// [CliRunner] adds `--help`, `--verbose`, `--quiet`, `--[no-]color`,
/// `--plain`, `--version` and the `completion` command.
class AppRunner extends CliRunner<int> {
  AppRunner({super.logger, Duration tick = const Duration(milliseconds: 400)})
      : super('__name__', 'A command-line app made with dart_tui.',
            version: '0.1.0') {
    addCommand(GreetCommand());
    addCommand(CountCommand(tick));
  }
}

/// `__name__ greet [name]`: says hello.
class GreetCommand extends CliCommand<int> {
  GreetCommand() {
    argParser.addFlag('shout', abbr: 's', help: 'Print it in capitals.');
  }

  @override
  String get name => 'greet';
  @override
  String get description => 'Say hello. Asks for a name when none is given.';
  @override
  String get category => 'Basics';
  @override
  String get invocation => '__name__ greet [name]';
  @override
  List<String> get examples => ['__name__ greet Ada', '__name__ greet --shout'];

  @override
  Future<int> run() async {
    final words = argResults!.rest;
    final name = words.isNotEmpty
        ? words.join(' ')
        : await logger.prompt('What is your name?', defaultValue: 'friend');
    final greeting = 'Hello, $name!';
    logger
        .success(argResults!.flag('shout') ? greeting.toUpperCase() : greeting);
    return 0;
  }
}

/// `__name__ count`: counts up with a progress line.
class CountCommand extends CliCommand<int> {
  CountCommand(this.tick) {
    argParser.addOption(
      'to',
      abbr: 't',
      valueHelp: 'n',
      help: 'The number to count to.',
      defaultsTo: '3',
    );
  }

  /// The pause between two numbers.
  final Duration tick;

  @override
  String get name => 'count';
  @override
  String get description => 'Count to a number, with a progress line.';
  @override
  String get category => 'Basics';
  @override
  bool get takesArguments => false;
  @override
  List<String> get examples => ['__name__ count --to 5'];

  @override
  Future<int> run() async {
    final to = int.tryParse(argResults!.option('to')!);
    if (to == null || to < 1) usageException('--to must be a number above 0.');
    final progress = logger.progress('Counting');
    for (var n = 1; n <= to; n++) {
      await Future<void>.delayed(tick);
      progress.update('Counting: $n of $to');
    }
    progress.complete('Counted to $to');
    return 0;
  }
}
