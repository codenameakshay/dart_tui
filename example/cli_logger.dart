// A "create project" flow with the mason_logger-shaped Logger.
//   dart run example/cli_logger.dart          (terminal UI)
//   dart run example/cli_logger.dart | cat    (plain line questions)

import 'package:dart_tui/cli.dart';

Future<void> main() async {
  final logger = Logger();
  await createProject(logger);
}

/// The whole flow; the test drives it with a fake stdin.
Future<void> createProject(
  Logger logger, {
  Duration step = const Duration(milliseconds: 900),
}) async {
  final name = await logger.prompt('Project name?', defaultValue: 'my_app');
  final template = await logger.chooseOne(
    'Template?',
    choices: const ['cli', 'server', 'package'],
    defaultValue: 'cli',
  );
  final features = await logger.chooseAny(
    'Features?',
    choices: const ['tests', 'lints', 'ci', 'docker'],
    defaultValues: const ['tests', 'lints'],
  );
  if (!await logger.confirm('Create $name?', defaultValue: true)) {
    logger.warn('Cancelled.');
    return;
  }

  final files = logger.progress('Writing $template files');
  await Future<void>.delayed(step);
  logger.detail('wrote pubspec.yaml');
  files.complete('Wrote ${3 + features.length} files');

  final deps = logger.progress('Getting dependencies');
  await Future<void>.delayed(step);
  deps.complete();

  logger
    ..info('')
    ..success('Created $name with ${features.join(', ')}.');
}
