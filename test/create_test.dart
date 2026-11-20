// `dart_tui create`: the wizard, the flags, the safety rules, and the
// generated templates. test/create_starters_test.dart builds the starters.
import 'dart:async';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/src/create/create.dart';
import 'package:dart_tui/src/create/templates.g.dart';
import 'package:dart_tui/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/gen_templates.dart' as gen;

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

void main() {
  late Directory tmp;
  late CaptureSink out;
  late CaptureSink err;
  late List<String> ran;
  var failPubGet = false;
  var failGit = false;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dart_tui_create');
    addTearDown(() => tmp.deleteSync(recursive: true));
    out = CaptureSink();
    err = CaptureSink();
    ran = [];
    failPubGet = false;
    failGit = false;
  });

  Future<int> fakeRun(
    String exe,
    List<String> args, {
    required String workingDirectory,
    required void Function(String line) log,
  }) async {
    final command = '${p.basenameWithoutExtension(exe)} ${args.join(' ')}';
    ran.add(command);
    if (command == 'dart pub get' && failPubGet) {
      log('Because demo depends on nothing that exists, version solving '
          'failed.');
      return 69;
    }
    if (command == 'git init' && failGit) return 1;
    return 0;
  }

  /// A runner whose logger writes to [out] and [err]. [plain] asks plain
  /// line questions, as in a pipe.
  DartTuiRunner runner({bool plain = false, Stream<List<int>>? stdin}) =>
      DartTuiRunner(
        logger: Logger(
          stdout: out,
          stderr: err,
          stdin: stdin,
          environment: {if (plain) 'ACCESSIBLE': '1'},
          exit: (code) => throw _Exit(code),
        ),
        runProcess: fakeRun,
      );

  Future<int> exitCodeOf(List<String> args, {bool plain = true}) async {
    try {
      await runner(plain: plain).runAndExit(args);
    } on _Exit catch (e) {
      return e.code;
    }
  }

  String dir(String name) => p.join(tmp.path, name);
  Set<String> files(String root) => {
        for (final f in Directory(root).listSync(recursive: true))
          if (f is File) p.relative(f.path, from: root).replaceAll(r'\', '/'),
      };

  test('the generated templates match templates/ and pubspec.yaml', () {
    // Run `dart run tool/gen_templates.dart` when this fails.
    expect(packageVersion, gen.readVersion());
    expect(starterFiles, gen.readTemplates());
    expect(starterFiles.keys.toSet(), starters.keys.toSet());
  });

  test('the wizard asks for the name, the starter and git init', () async {
    final target = dir('My-Tool');
    final t = TuiTester.run(() => runner().run(['create', target]));
    addTearDown(t.dispose);

    // The default name comes from the directory.
    await t.waitFor((s) => s.contains('Project name? (my_tool)'));
    await t.type('Bad-Name');
    await t.press('enter');
    // An invalid answer asks again.
    await t.waitFor((s) => s.contains('Project name? (my_tool)'));
    expect(err.text, contains('"Bad-Name" is not a valid package name'));
    await t.press('enter');

    await t.waitFor((s) => s.contains('Starter?'));
    expect(t.screen, contains('> app    A full-screen app with a list'));
    await t.press('up');
    await t.press('enter');

    await t.waitFor((s) => s.contains('Run git init?'));
    await t.press('n');
    expect((await t.done()).value, 0);

    expect(files(target), {
      '.gitignore',
      'README.md',
      'analysis_options.yaml',
      'bin/my_tool.dart',
      'lib/my_tool.dart',
      'pubspec.yaml',
      'test/my_tool_test.dart',
    });
    expect(File(p.join(target, 'pubspec.yaml')).readAsStringSync(),
        startsWith('name: my_tool\n'));
    expect(ran, ['dart pub get']);
    expect(out.text, contains('Writing the cli starter in'));
    expect(out.text, contains('  dart run my_tool --help\n  dart test\n'));
  });

  test('with every flag given it never prompts', () async {
    final target = dir('demo');
    // No input at all: a prompt would wait forever.
    final code = await runner().run([
      'create', target, '--template', 'script', '--name', 'hello', //
      '--no-git',
    ]);
    expect(code, 0);
    expect(files(target), contains('bin/hello.dart'));
    expect(ran, ['dart pub get']);
    expect(out.text, isNot(contains('?')));
  });

  test('plain mode reads no input and runs both commands', () async {
    final stdin = StreamController<List<int>>();
    // close() never completes without a listener, so it is not awaited.
    addTearDown(() => unawaited(stdin.close()));
    final target = dir('plain_app');
    final code = await runner(plain: true, stdin: stdin.stream)
        .run(['create', target, '-t', 'app']);
    expect(code, 0);
    expect(stdin.hasListener, isFalse);
    expect(ran, ['dart pub get', 'git init']);
    expect(out.text, contains('✓ dart pub get'));
    expect(out.text, contains('Created plain_app.'));
    expect(out.text, contains('  cd ${_quoted(target)}\n  dart run\n'));
    expect(files(target), contains('test/plain_app_test.dart'));
  });

  test('--no-pub-get puts dart pub get in the next steps', () async {
    final target = dir('x');
    await runner(plain: true)
        .run(['create', target, '-t', 'app', '--no-pub-get', '--no-git']);
    expect(ran, isEmpty);
    expect(out.text, contains('  dart pub get\n  dart run\n'));
  });

  group('without a terminal a missing value exits 64 and names it', () {
    test('--template', () async {
      expect(await exitCodeOf(['create', dir('a')]), 64);
      expect(err.text, contains('Missing --template.'));
      expect(Directory(dir('a')).existsSync(), isFalse);
    });

    test('the directory', () async {
      expect(await exitCodeOf(['create', '--template', 'cli']), 64);
      expect(err.text, contains('Missing the directory.'));
    });

    test('an unknown starter', () async {
      expect(await exitCodeOf(['create', dir('a'), '-t', 'web']), 64);
      expect(err.text, contains('"web" is not an allowed value'));
    });

    test('two directories', () async {
      expect(await exitCodeOf(['create', 'a', 'b', '-t', 'cli']), 64);
      expect(err.text, contains('Give one directory, not 2.'));
    });
  });

  for (final name in [
    'My-App',
    '1app',
    'class',
    'dart_tui',
    'sealed',
    'type',
    ''
  ]) {
    test('--name "$name" is refused', () async {
      expect(
          await exitCodeOf(['create', dir('a'), '-t', 'cli', '--name', name]),
          64);
      expect(err.text, contains('is not a valid package name'));
      expect(Directory(dir('a')).existsSync(), isFalse);
    });
  }

  test('packageNameFor makes a valid name from any directory', () {
    expect(packageNameFor('My-App'), 'my_app');
    expect(packageNameFor('/x/2048'), 'app_2048');
    expect(packageNameFor('class'), 'class_app');
    expect(packageNameFor('sealed'), 'sealed_app');
    expect(packageNameFor('type'), 'type_app');
    expect(packageNameFor('dart_tui'), 'dart_tui_app');
    expect(packageNameFor('---'), 'my_app');
  });

  group('a directory that is not empty', () {
    late String target;
    setUp(() {
      target = dir('busy');
      Directory(p.join(target, 'bin')).createSync(recursive: true);
      File(p.join(target, 'notes.txt')).writeAsStringSync('keep me');
      File(p.join(target, 'bin', 'busy.dart')).writeAsStringSync('old');
    });

    test('is refused without --force', () async {
      expect(await exitCodeOf(['create', target, '-t', 'script']), 73);
      expect(err.text, contains('is not empty. Pass --force'));
      expect(
          File(p.join(target, 'bin', 'busy.dart')).readAsStringSync(), 'old');
      expect(ran, isEmpty);
    });

    test('with --force gets the files added and listed, nothing deleted',
        () async {
      expect(
          await runner(plain: true)
              .run(['create', target, '-t', 'script', '--force', '--no-git']),
          0);
      expect(File(p.join(target, 'notes.txt')).readAsStringSync(), 'keep me');
      expect(File(p.join(target, 'bin', 'busy.dart')).readAsStringSync(),
          contains('package:dart_tui/cli.dart'));
      expect(out.text, contains('  overwrote bin/busy.dart\n'));
      expect(out.text, contains('  created pubspec.yaml\n'));
    });

    test('a file in the way is refused even with --force', () async {
      final file = p.join(target, 'notes.txt');
      expect(await exitCodeOf(['create', file, '-t', 'cli', '--force']), 73);
      expect(err.text, contains('exists and is not a directory'));
    });
  });

  for (final blocked in ['bin', 'pubspec.yaml', 'bin/demo.dart']) {
    test('refuses a conflicting template path $blocked before writing',
        () async {
      final target = dir('demo');
      Directory(target).createSync();
      final path = p.join(target, blocked);
      if (blocked == 'bin') {
        File(path).writeAsStringSync('keep me');
      } else {
        Directory(path).createSync(recursive: true);
      }
      expect(
          await exitCodeOf(['create', target, '-t', 'script', '--force']), 73);
      expect(err.text, contains('cannot write'));
      expect(File(p.join(target, 'README.md')).existsSync(), isFalse);
      expect(ran, isEmpty);
    });
  }

  test('refuses a file above a new target directory', () async {
    final parent = dir('file');
    File(parent).writeAsStringSync('keep me');
    expect(await exitCodeOf(['create', p.join(parent, 'demo'), '-t', 'script']),
        73);
    expect(File(parent).readAsStringSync(), 'keep me');
    expect(ran, isEmpty);
  });

  test('refuses a dangling symlink at or above the target', () async {
    final link = dir('broken');
    Link(link).createSync(dir('missing'));
    for (final target in [link, p.join(link, 'demo')]) {
      expect(
          await exitCodeOf(['create', target, '-t', 'script', '--force']), 73);
    }
    expect(Directory(dir('missing')).existsSync(), isFalse);
    expect(ran, isEmpty);
  }, skip: Platform.isWindows);

  test('does not follow template symlinks outside the target', () async {
    final target = dir('demo');
    Directory(target).createSync();
    final outside = dir('outside');
    Directory(outside).createSync();
    Link(p.join(target, 'bin')).createSync(outside);
    expect(await exitCodeOf(['create', target, '-t', 'script', '--force']), 73);
    expect(Directory(outside).listSync(), isEmpty);
    expect(File(p.join(target, 'README.md')).existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test('next steps quote shell metacharacters in directory names', () async {
    final target = dir(r'demo $HOME `whoami` "quoted"; touch nope');
    expect(
        await runner(plain: true).run(
            ['create', target, '-t', 'script', '--no-git', '--no-pub-get']),
        0);
    final cd =
        out.text.split('\n').singleWhere((line) => line.startsWith('  cd '));
    final result = await Process.run('sh', ['-c', '${cd.trim()} && pwd']);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), target);
  }, skip: Platform.isWindows);

  test('a failed pub get keeps the files and prints the command', () async {
    failPubGet = true;
    final target = dir('demo');
    expect(await exitCodeOf(['create', target, '-t', 'app']), 1);
    expect(files(target), contains('pubspec.yaml'));
    // git init still runs.
    expect(ran, ['dart pub get', 'git init']);
    expect(err.text, contains('version solving failed'));
    expect(
        err.text,
        contains('dart pub get failed. The files are in place; fix the '
            'problem and run it again: cd ${_quoted(target)} && '
            'dart pub get'));
    expect(out.text, contains('✗ dart pub get'));
  });

  test('a failed git init keeps files and exits 1 with a retry command',
      () async {
    failGit = true;
    final target = dir('demo');
    expect(await exitCodeOf(['create', target, '-t', 'app']), 1);
    expect(files(target), contains('pubspec.yaml'));
    expect(ran, ['dart pub get', 'git init']);
    expect(
        err.text,
        contains('git init failed. The files are in place; fix '
            'the problem and run it again: cd ${_quoted(target)} && git init'));
  });

  test('the same runner can retry a failed create without stale failures',
      () async {
    failPubGet = true;
    final target = dir('retry');
    final r = runner(plain: true);
    final args = ['create', target, '-t', 'script'];
    expect(await r.run(args), 1);
    File(p.join(target, 'notes.txt')).writeAsStringSync('keep me');
    failPubGet = false;
    expect(await r.run([...args, '--force']), 0);
    expect(ran, ['dart pub get', 'git init', 'dart pub get', 'git init']);
    expect(File(p.join(target, 'notes.txt')).readAsStringSync(), 'keep me');
  });

  test('a command that cannot start is a failure too', () async {
    final logger = Logger(
        stdout: out, stderr: err, environment: const {'ACCESSIBLE': '1'});
    final r = DartTuiRunner(
      logger: logger,
      runProcess: (exe, args, {required workingDirectory, required log}) =>
          throw ProcessException(exe, args, 'No such file'),
    );
    expect(await r.run(['create', dir('a'), '-t', 'app', '--no-pub-get']), 1);
    expect(err.text, contains('git init failed.'));
  });

  group('the executable', () {
    Future<ProcessResult> dartTui(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          ['bin/dart_tui.dart', ...args],
          environment: {'NO_COLOR': '1'},
        );

    test('--help lists create', () async {
      final r = await dartTui(['--help']);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('create       Make a new project'));
    });

    test('create --help lists the flags', () async {
      final r = await dartTui(['create', '--help']);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('--template'));
      expect(r.stdout, contains('--[no-]pub-get'));
    });

    test('completion zsh prints a script', () async {
      final r = await dartTui(['completion', 'zsh']);
      expect(r.exitCode, 0);
      expect(r.stdout, startsWith('#compdef dart_tui'));
    });

    test('with no terminal a missing --template exits 64', () async {
      final r = await dartTui(['create', dir('a')]);
      expect(r.exitCode, 64);
      expect(r.stderr, contains('Missing --template.'));
    });
  });

  test('runs real commands', () async {
    final target = dir('real');
    final r = DartTuiRunner(
        logger: Logger(
            stdout: out, stderr: err, environment: const {'ACCESSIBLE': '1'}));
    expect(await r.run(['create', target, '-t', 'script', '--no-pub-get']), 0,
        reason: err.text);
    expect(Directory(p.join(target, '.git')).existsSync(), isTrue);
  }, skip: _hasGit ? false : 'git is not installed');
}

String _quoted(String path) => path.contains(' ') ? '"$path"' : path;

final _hasGit = () {
  try {
    return Process.runSync('git', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
