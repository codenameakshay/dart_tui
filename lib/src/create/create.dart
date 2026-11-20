/// The `dart_tui` executable: `dart_tui create` makes a starter project.
///
/// Internal: bin/dart_tui.dart runs it. Not exported.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../cli.dart';
import 'templates.g.dart';

/// Runs [executable] in [workingDirectory], sends each output line to [log]
/// and returns the exit code. Throws [ProcessException] when it cannot start.
typedef RunProcess = Future<int> Function(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required void Function(String line) log,
});

/// The starters, in the order the wizard shows them.
const starters = {
  'script': 'One file that asks questions',
  'cli': 'A CLI with commands and completions',
  'app': 'A full-screen app with a list',
};

/// The `dart_tui` command.
class DartTuiRunner extends CliRunner<int> {
  DartTuiRunner({super.logger, RunProcess? runProcess})
      : super('dart_tui', 'Make terminal apps with dart_tui.',
            version: packageVersion) {
    addCommand(CreateCommand(runProcess ?? _runProcess));
  }

  @override
  String get usageFooter => 'Docs: https://dart-tui.vercel.app';
}

/// `dart_tui create [directory]`.
class CreateCommand extends CliCommand<int> {
  CreateCommand(this._run) {
    argParser
      ..addOption(
        'template',
        abbr: 't',
        help: 'The starter to make.',
        allowed: starters.keys,
        allowedHelp: starters,
      )
      ..addOption(
        'name',
        valueHelp: 'package',
        help: 'The package name. Defaults to one made from the directory '
            'name.',
      )
      ..addFlag('git', defaultsTo: true, help: 'Run git init.')
      ..addFlag('pub-get', defaultsTo: true, help: 'Run dart pub get.')
      ..addFlag(
        'force',
        negatable: false,
        help: 'Write into a directory that is not empty. Only adds or '
            "overwrites the starter's files; never deletes.",
      );
  }

  final RunProcess _run;

  @override
  String get name => 'create';
  @override
  String get description => 'Make a new project from a starter.\n\n'
      'On a terminal it asks for each value you do not give. Without one '
      '(CI, pipes, --plain) it never asks: give the directory and '
      '--template.';
  @override
  String get invocation => 'dart_tui create [directory] [arguments]';
  @override
  List<String> get examples => [
        'dart_tui create',
        'dart_tui create my_app --template app',
        'dart_tui create tool --template cli --name my_tool --no-git',
      ];

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length > 1) {
      usageException('Give one directory, not ${args.rest.length}.');
    }
    var dir = args.rest.isEmpty ? null : args.rest.single;
    var template = args.option('template');
    final plain = loggerIsPlain(logger);
    if (plain && dir == null) {
      usageException('Missing the directory. There is no terminal to ask '
          'on, so give it: dart_tui create <directory> --template <starter>');
    }
    if (plain && template == null) {
      usageException('Missing --template. There is no terminal to ask on, so '
          'pass --template ${starters.keys.join('|')}.');
    }
    // With a directory and a starter given, an agent or script can run it
    // on a terminal too: nothing is asked, the rest take their defaults.
    final ask = !plain && (dir == null || template == null);
    final force = args.flag('force');
    if (dir != null && _refuse(dir, force)) return 73;

    var name = args.option('name');
    if (name != null) {
      if (nameProblem(name) case final problem?) {
        usageException('--name "$name" is not a valid package name: '
            '$problem.');
      }
    } else if (!ask) {
      name = packageNameFor(dir!);
    } else {
      final fallback = dir == null ? 'my_app' : packageNameFor(dir);
      while (name == null) {
        final answer =
            await logger.prompt('Project name?', defaultValue: fallback);
        if (nameProblem(answer) case final problem?) {
          logger.err('"$answer" is not a valid package name: $problem.');
        } else {
          name = answer;
        }
      }
    }
    if (dir == null) {
      dir = name;
      if (_refuse(dir, force)) return 73;
    }

    template ??= await logger.chooseOne<String>(
      'Starter?',
      choices: starters.keys.toList(),
      defaultValue: 'app',
      display: (key) => '${key.padRight(6)} ${starters[key]}',
    );
    final git = ask && !args.wasParsed('git')
        ? await logger.confirm('Run git init?', defaultValue: true)
        : args.flag('git');
    final pubGet = args.flag('pub-get');

    final root = p.normalize(p.absolute(dir));
    final shown = _shown(root);
    final files = {
      for (final entry in starterFiles[template]!.entries)
        entry.key.replaceAll('__name__', name):
            entry.value.replaceAll('__name__', name),
    };
    if (_refuseFiles(root, files.keys)) return 73;
    logger.info('Writing the $template starter in $shown:');
    for (final MapEntry(key: relative, value: content) in files.entries) {
      final file = File(p.joinAll([root, ...relative.split('/')]));
      final existed = file.existsSync();
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      logger.info('  ${existed ? 'overwrote' : 'created'} $relative');
    }

    // Commands to run again by hand.
    final failed = <String>[];
    // The live list shows each command's last line. Plain output (CI,
    // agents) gets none. A failed command prints all of it to stderr.
    final echo = !plain || logger.level == Level.verbose;
    Future<void> step(TaskContext task, String exe, List<String> argv) async {
      final command = '${p.basenameWithoutExtension(exe)} ${argv.join(' ')}';
      final output = <String>[];
      void log(String line) {
        output.add(line);
        if (echo) task.log(line);
      }

      int code;
      try {
        code = await _run(exe, argv, workingDirectory: root, log: log);
      } on ProcessException catch (e) {
        failed.add(command);
        throw 'could not start ${e.executable}: ${e.message}';
      }
      if (code != 0) {
        failed.add(command);
        output.forEach(logger.err);
        throw 'exited with code $code';
      }
    }

    await logger.tasks(exitOnError: false, [
      if (pubGet)
        Task('dart pub get', (task) => step(task, _dart, ['pub', 'get'])),
      if (git) Task('git init', (task) => step(task, 'git', ['init'])),
    ]);

    final cd = p.equals(root, p.current) ? null : 'cd ${quotePath(shown)}';
    logger
      ..info('')
      ..success('Created $name.')
      ..info('')
      ..info('Next steps:');
    for (final line in [
      if (cd != null) cd,
      if (!pubGet || failed.contains('dart pub get')) 'dart pub get',
      template == 'cli' ? 'dart run $name --help' : 'dart run',
      'dart test',
    ]) {
      logger.info('  $line');
    }
    for (final command in failed) {
      logger.err('$command failed. The files are in place; fix the problem '
          'and run it again: ${cd == null ? '' : '$cd && '}$command');
    }
    return failed.isEmpty ? 0 : 1;
  }

  bool _refuseFiles(String root, Iterable<String> paths) {
    for (final relative in paths) {
      final path = p.joinAll([root, ...relative.split('/')]);
      var current = path;
      var isFile = true;
      while (true) {
        final type = FileSystemEntity.typeSync(current,
            followLinks: !isFile && !p.isWithin(root, current));
        if ((type != FileSystemEntityType.notFound ||
                FileSystemEntity.isLinkSync(current)) &&
            type !=
                (isFile
                    ? FileSystemEntityType.file
                    : FileSystemEntityType.directory)) {
          logger.err('${_shown(current)} is in the way; cannot write '
              '$relative.');
          return true;
        }
        final parent = p.dirname(current);
        if (parent == current) break;
        current = parent;
        isFile = false;
      }
    }
    return false;
  }

  /// Prints why [dir] cannot be used and returns true, or returns false.
  bool _refuse(String dir, bool force) {
    final path = p.absolute(dir);
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      logger.err('${_shown(path)} exists and is not a directory.');
      return true;
    }
    if (force || Directory(path).listSync().isEmpty) return false;
    logger.err("${_shown(path)} is not empty. Pass --force to add the "
        "starter's files to it: files with the same names are overwritten, "
        'and nothing is deleted.');
    return true;
  }
}

/// Why [name] is not a valid package name for a starter, or null.
String? nameProblem(String name) {
  if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(name)) {
    return 'use lowercase letters, digits and underscores, and do not start '
        'with a digit';
  }
  if (_reservedWords.contains(name)) return 'it is a reserved word in Dart';
  if (name == 'dart_tui') {
    return 'the starter depends on dart_tui, so it needs another name';
  }
  return null;
}

/// A valid package name made from [dir]'s last part, such as `my_app` for
/// `../My-App`.
String packageNameFor(String dir) {
  var name = p
      .basename(p.normalize(p.absolute(dir)))
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9_]+'), '_');
  if (name.isEmpty || RegExp(r'^_*$').hasMatch(name)) return 'my_app';
  if (RegExp('^[0-9]').hasMatch(name)) name = 'app_$name';
  return nameProblem(name) == null ? name : '${name}_app';
}

/// The words pub does not accept as a package name.
const _reservedWords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', //
  'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
  'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
  'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'inout', 'interface', 'is', 'late',
  'library', 'mixin', 'native', 'new', 'null', 'of', 'on', 'operator', 'out',
  'part', 'patch', 'required', 'rethrow', 'return', 'set', 'show', 'source',
  'sealed', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try',
  'type', 'typedef', 'var', 'void', 'while', 'with', 'yield',
};

/// [path] relative to the current directory when it is inside it.
String _shown(String path) =>
    p.isWithin(p.current, path) ? p.relative(path) : path;

/// [path] as one word for the user's shell: as it is when it is safe,
/// else in double quotes (with `\`, `"`, `$` and backticks escaped off
/// Windows).
String quotePath(String path) {
  if (RegExp(r'^[a-zA-Z0-9_./:-]+$').hasMatch(path)) return path;
  if (Platform.isWindows) return '"$path"';
  final escaped = path
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('`', r'\`');
  return '"$escaped"';
}

/// The running `dart`, or `dart` from PATH in a compiled executable.
String get _dart {
  final exe = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(exe) == 'dart' ? exe : 'dart';
}

Future<int> _runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required void Function(String line) log,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    // dart may be a .bat file on Windows (Flutter's), which needs a shell.
    runInShell: Platform.isWindows && !p.isAbsolute(executable),
  );
  unawaited(process.stdin.close());
  await Future.wait([
    for (final stream in [process.stdout, process.stderr])
      stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach(log),
  ]);
  return process.exitCode;
}
