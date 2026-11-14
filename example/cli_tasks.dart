// A "release" flow with Logger.tasks: checks run in parallel, the build has
// nested steps with streamed output, and publishing is skipped.
//   dart run example/cli_tasks.dart          (live task list)
//   dart run example/cli_tasks.dart | cat    (one plain line per change)
//   dart run example/cli_tasks.dart --fail   (a test fails)

import 'dart:io';

import 'package:dart_tui/cli.dart';

Future<void> main(List<String> args) async {
  try {
    await release(Logger(), fail: args.contains('--fail'));
  } on TasksFailed {
    exitCode = 1;
  }
}

/// The whole flow; [tick] scales every pause.
Future<void> release(
  Logger logger, {
  bool fail = false,
  Duration tick = const Duration(milliseconds: 200),
}) async {
  Future<void> work(TaskContext task, List<String> lines) async {
    for (final line in lines) {
      await Future<void>.delayed(tick);
      task.log(line);
    }
    await Future<void>.delayed(tick);
  }

  await logger.tasks([
    Task(
      'Check',
      (task) => task.tasks(concurrency: 3, [
        Task('Resolve dependencies', (task) async {
          await work(task, [
            'Resolving args 2.7.0',
            'Resolving characters 1.4.0',
            'Resolving path 1.9.1',
            'Got dependencies',
          ]);
        }),
        Task('Run tests', (task) async {
          await work(task, [
            '+12: test/cli_logger_test.dart',
            '+48: test/cli_runner_test.dart',
            if (fail) '-1: test/cli_tasks_test.dart: summary line',
            '+97: test/renderer_test.dart',
          ]);
          if (fail) throw Exception('1 test failed');
        }),
        Task('Analyze', (task) => work(task, ['No issues found'])),
      ]),
    ),
    Task(
      'Build',
      (task) => task.tasks([
        Task('Compile', (task) async {
          for (final target in ['linux-x64', 'macos-arm64', 'windows-x64']) {
            task.title = 'Compile $target';
            await work(task, ['Generated bin/release-$target']);
          }
          task.title = 'Compile 3 targets';
        }),
        Task('Archive', (task) async {
          await work(task, [
            'Adding bin/release-linux-x64',
            'Adding bin/release-macos-arm64',
            'Adding bin/release-windows-x64',
            'Wrote release.tar.gz (8.2 MB)',
          ]);
        }),
      ]),
    ),
    Task('Publish', (task) => task.skip('dry run')),
  ]);
}
