/// A `mason_logger`-shaped [Logger] for command-line tools, with dart_tui
/// prompts, plain mode and colour detection.
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
/// See the migration guide for the differences from `mason_logger`.
library;

export 'src/cli.dart' show Level, Logger, Progress, ProgressOptions;
