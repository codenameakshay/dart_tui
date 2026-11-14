/// Tools for command-line apps: a `mason_logger`-shaped [Logger] with
/// dart_tui prompts, plain mode and colour detection, and [CliRunner], a
/// `package:args` command runner with styled help and standard flags.
///
/// ```dart
/// import 'package:dart_tui/cli.dart';
///
/// final logger = Logger();
/// final name = await logger.prompt('Project name?', defaultValue: 'app');
/// final progress = logger.progress('Creating $name');
/// // ...
/// progress.complete();
/// ```
///
/// See the migration guide for the differences from `mason_logger`, and the
/// guide "Build a CLI with commands" for [CliRunner].
library;

export 'package:args/command_runner.dart' show UsageException;

export 'src/cli.dart'
    show CliCommand, CliRunner, Level, Logger, Progress, ProgressOptions;
