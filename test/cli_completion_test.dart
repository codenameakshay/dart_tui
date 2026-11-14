import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart' show Command;
import 'package:dart_tui/cli.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

import '../example/cli_app/notes.dart';

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

Never _throwExit(int code) => throw _Exit(code);

Logger _logger(CaptureSink out,
        {CaptureSink? err, Map<String, String> env = const {}}) =>
    Logger(
      stdout: out,
      stderr: err ?? CaptureSink(),
      environment: env,
      exit: _throwExit,
    );

/// `tool deploy` (options of every kind), `tool remote add|remove` (an
/// alias and a hidden subcommand) and a hidden `secret`.
CliRunner<int> _tool(CaptureSink out, {bool completions = true}) =>
    CliRunner<int>('tool', 'A test tool.',
        logger: _logger(out), completions: completions)
      ..addCommand(_Deploy())
      ..addCommand(_Remote())
      ..addCommand(_Secret());

final class _Deploy extends CliCommand<int> {
  _Deploy() {
    argParser
      ..addOption('env',
          abbr: 'e',
          allowed: ['dev', 'prod'],
          allowedHelp: {'dev': 'Development.', 'prod': 'Production.'})
      ..addOption('target', help: 'Where to.')
      ..addOption('out', help: 'Output path.\nSecond line.')
      ..addFlag('dry-run', negatable: false, help: 'Change nothing.')
      ..addFlag('cache', help: 'Use the cache.')
      ..addOption('secret-opt', hide: true);
  }

  @override
  String get name => 'deploy';
  @override
  String get description => 'Ship it.';

  final calls = <(String, String)>[];

  @override
  Future<Iterable<String>> completeValue(String option, String partial) async {
    calls.add((option, partial));
    return switch (option) {
      'target' => ['web', 'ios\tThe iPhone app'],
      '' => ['v1', 'v2'],
      _ => const [],
    };
  }

  @override
  int run() => 0;
}

final class _Remote extends CliCommand<int> {
  _Remote() {
    addSubcommand(_Sub('add', aliases: ['new']));
    addSubcommand(_Sub('remove'));
    addSubcommand(_Sub('prune', hidden: true));
  }

  @override
  String get name => 'remote';
  @override
  String get description => 'Manage remotes.';
}

final class _Sub extends CliCommand<int> {
  _Sub(this.name, {this.aliases = const [], this.hidden = false}) {
    argParser.addFlag('force', abbr: 'F');
  }

  @override
  final String name;
  @override
  final List<String> aliases;
  @override
  final bool hidden;
  @override
  String get description => 'The $name command.';
  @override
  int run() => 0;
}

final class _Secret extends CliCommand<int> {
  @override
  String get name => 'secret';
  @override
  String get description => 'Hidden.';
  @override
  bool get hidden => true;
  @override
  int run() => 0;
}

void main() {
  late CaptureSink out;
  setUp(() => out = CaptureSink());

  /// The lines `__complete` prints for [words] on [runner] (default: tool).
  Future<List<String>> complete(List<String> words,
      {CliRunner<int>? runner}) async {
    out.clear();
    await (runner ?? _tool(out)).run(['__complete', ...words]);
    final lines = out.text.split('\n');
    expect(lines.last, '', reason: 'ends with a newline');
    return lines..removeLast();
  }

  group('__complete', () {
    test('an empty word lists commands with descriptions, not hidden ones',
        () async {
      expect(await complete(['']), [
        'deploy\tShip it.',
        'remote\tManage remotes.',
        'completion\tSet up shell completion.',
        ':4',
      ]);
    });

    test('a partial command', () async {
      expect(await complete(['de']), ['deploy\tShip it.', ':4']);
      expect(await complete(['zzz']), [':4']);
    });

    test('nested subcommands, aliases, and hidden ones left out', () async {
      expect(await complete(['remote', '']), [
        'add\tThe add command.',
        'new\tThe add command.',
        'remove\tThe remove command.',
        ':4',
      ]);
      expect(await complete(['remote', 'n']), ['new\tThe add command.', ':4']);
      // A hidden command still works when typed.
      expect(await complete(['remote', 'prune', '--f']), ['--force', ':4']);
    });

    test('flags for the command the words reach, then the global flags',
        () async {
      final lines = await complete(['remote', 'add', '-']);
      expect(lines, containsAllInOrder(['--force', '--no-force', '-F']));
      expect(
          lines,
          contains('--verbose\tShow all log output, and stack '
              'traces on errors.'));
      expect(
          lines,
          contains('-v\tShow all log output, and stack traces on '
              'errors.'));
      expect(lines.where((l) => l.startsWith('--help')), hasLength(1),
          reason: 'help appears once');
      expect(lines.last, ':4');

      final deploy = await complete(['deploy', '--']);
      expect(deploy, contains('--dry-run\tChange nothing.'));
      expect(deploy, isNot(contains(startsWith('--no-dry-run'))));
      expect(deploy, contains('--no-cache\tUse the cache.'));
      expect(deploy, contains('--out\tOutput path.'), reason: 'first line');
      expect(deploy, isNot(contains(startsWith('--secret-opt'))));
      expect(deploy, isNot(contains(startsWith('-v'))), reason: 'long only');
    });

    test('flags after other flags and values', () async {
      expect(await complete(['-v', 'deploy', '-e', 'dev', '--d']),
          ['--dry-run\tChange nothing.', ':4']);
    });

    test('allowed values with their help, after --opt= and --opt <space>',
        () async {
      expect(await complete(['deploy', '--env=']), [
        '--env=dev\tDevelopment.',
        '--env=prod\tProduction.',
        ':4',
      ]);
      expect(await complete(['deploy', '--env=p']),
          ['--env=prod\tProduction.', ':4']);
      expect(await complete(['deploy', '--env', '']),
          ['dev\tDevelopment.', 'prod\tProduction.', ':4']);
      expect(
          await complete(['deploy', '-e', 'd']), ['dev\tDevelopment.', ':4']);
      expect(
          await complete(['deploy', '-Fe', 'd']), ['dev\tDevelopment.', ':4'],
          reason: 'a value option at the end of a group');
      expect(await complete(['deploy', '-edev', '']), ['v1', 'v2', ':4'],
          reason: 'the value was in the same word');
    });

    test('an option with no allowed values and no hook gets files', () async {
      expect(await complete(['deploy', '--out', '']), [':0']);
      expect(await complete(['deploy', '--out=']), [':0']);
      // A flag takes no value, and an unknown option has none.
      expect(await complete(['deploy', '--cache=']), [':4']);
      expect(await complete(['deploy', '--nope=']), [':4']);
    });

    test('the hook completes option values and positional arguments', () async {
      final runner = _tool(out);
      final deploy = runner.commands['deploy']! as _Deploy;
      expect(await complete(['deploy', '--target', ''], runner: runner),
          ['web', 'ios\tThe iPhone app', ':4']);
      out.clear();
      expect(await complete(['deploy', '--target=i'], runner: runner),
          ['--target=ios\tThe iPhone app', ':4']);
      out.clear();
      expect(
          await complete(['deploy', 'v'], runner: runner), ['v1', 'v2', ':4']);
      out.clear();
      expect(await complete(['deploy', 'x'], runner: runner), [':4']);
      expect(deploy.calls,
          [('target', ''), ('target', 'i'), ('', 'v'), ('', 'x')]);
    });

    test(
        'a positional with no hook values gets files, unless the command '
        'takes no arguments', () async {
      expect(await complete(['remote', 'add', '']), [':0']);
      final notes = NotesRunner(logger: _logger(out));
      expect(await complete(['list', ''], runner: notes), [':4']);
    });

    test('after a positional, commands are no longer offered', () async {
      expect(await complete(['remote', 'zzz', '']), [':4']);
    });

    test('after --, words are positional', () async {
      expect(await complete(['deploy', '--', '-']), [':4']);
      out.clear();
      expect(await complete(['deploy', '--', '--', '']), ['v1', 'v2', ':4']);
    });

    test('help takes command names', () async {
      expect(
          await complete(['help', 'rem']), ['remote\tManage remotes.', ':4']);
      expect(await complete(['help', 'remote', 'a']),
          ['add\tThe add command.', ':4']);
    });

    test('a user args Command named help keeps its own subcommands', () async {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(_RemoteWithHelp());
      expect(await complete(['custom', 'help', ''], runner: runner),
          ['topic\tThe topic command.', ':4']);
    });

    test('the completion command completes its actions and shells', () async {
      expect(await complete(['completion', '']), [
        'bash',
        'zsh',
        'fish',
        'install',
        'uninstall',
        ':4',
      ]);
      expect(
          await complete(['completion', '-']),
          containsAll([
            '--yes\tEdit your .zshrc without asking (zsh install '
                'and uninstall).',
            '-y\tEdit your .zshrc without asking (zsh '
                'install and uninstall).'
          ]));
    });

    test('notes: commands, aliases and allowed values with help', () async {
      final notes = NotesRunner(logger: _logger(out));
      expect(await complete(['l'], runner: notes),
          ['list\tList the notes.', 'ls\tList the notes.', ':4']);
      out.clear();
      expect(await complete(['add', '--priority', ''], runner: notes), [
        'low\tSome day.',
        'normal\tThis week.',
        'high\tToday.',
        ':4',
      ]);
      out.clear();
      expect(await complete(['add', '-f', ''], runner: notes), [':0']);
    });

    test('descriptions are kept on one line', () async {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(_Sub('a\tb'));
      expect(await complete([''], runner: runner),
          contains('a b\tThe a b command.'));
    });

    test('styled descriptions never leak terminal escapes into the protocol',
        () async {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(_StyledCompletion());
      expect(await complete(['styled', '--value', ''], runner: runner),
          ['safe\tRed description', ':4']);
      expect(await complete(['styled', ''], runner: runner),
          ['safe\tHook description', ':4']);
    });

    test('an error prints nothing, and runAndExit exits 0', () async {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(_Throws());
      await expectLater(runner.runAndExit(['__complete', 'throws', '']),
          throwsA(isA<_Exit>().having((e) => e.code, 'code', 0)));
      expect(out.text, '');
    });

    test('runAndExit prints and exits 0, without parsing or the level',
        () async {
      final logger = _logger(out);
      final runner = CliRunner<int>('tool', 'x', logger: logger)
        ..argParser.addOption('token', mandatory: true)
        ..addCommand(_Sub('go'));
      await expectLater(
          runner.runAndExit(['__complete', '-q', '--verbose', 'g']),
          throwsA(isA<_Exit>().having((e) => e.code, 'code', 0)));
      expect(out.text, 'go\tThe go command.\n:4\n');
      expect(logger.level, Level.info);
    });

    test('completion hooks do not see results from a previous run', () async {
      final command = _ResultsProbe();
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(command);
      await runner.run(['probe', '--value', 'old']);
      expect(command.argResults, isNotNull);
      expect(await complete(['probe', ''], runner: runner), ['clean', ':4']);
      expect(command.argResults, isNotNull,
          reason: 'completion does not discard normal command state');
      await runner.run(['probe', '--value', 'new']);
      expect(command.argResults!.option('value'), 'new');
    });

    test('malformed completion words stay silent and never execute commands',
        () async {
      final err = CaptureSink();
      final logger = _logger(out, err: err, env: {'FORCE_COLOR': '3'});
      final command = _NeverRun();
      final runner = CliRunner<int>('tool', 'x', logger: logger)
        ..argParser.addOption('required', mandatory: true)
        ..addCommand(command);
      for (final words in [
        ['probe', '--unknown=', '--value', '\u001b[31m'],
        ['probe', '-xyz', '--', '\n'],
        ['--quiet', '--verbose', 'probe', '--value=bad'],
      ]) {
        out.clear();
        await expectLater(runner.runAndExit(['__complete', ...words]),
            throwsA(isA<_Exit>().having((e) => e.code, 'code', 0)));
        expect(out.text, isNot(contains('\u001b')));
        expect(err.text, '');
        expect(logger.level, Level.info);
        expect(command.runs, 0);
      }
    });

    test('an empty word list completes commands', () async {
      expect(await complete([]), contains(startsWith('deploy')));
    });

    test('a user command named completion wins, and __complete still works',
        () async {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..argParser.addFlag('yes', abbr: 'y')
        ..addCommand(_Sub('completion'));
      expect(await complete(['comp'], runner: runner),
          ['completion\tThe completion command.', ':4']);
      expect(runner.commands['completion'], isA<_Sub>());
      expect(runner.usage, contains('--[no-]yes'));
    });

    test('a user __complete command wins over the protocol', () async {
      final mine = _Sub('__complete');
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out))
        ..addCommand(mine);
      expect(await runner.run(['__complete']), 0);
      expect(out.text, '');
      expect(runner.commands['__complete'], same(mine));
      expect(runner.commands['completion'], isNotNull);
    });

    test('completions: false adds neither command', () async {
      final runner = _tool(out, completions: false);
      await expectLater(
          runner.run(['__complete', '']), throwsA(isA<UsageException>()));
      expect(runner.commands.keys, isNot(contains('completion')));
    });

    test('a runner with no commands gets no completion commands', () {
      final runner = CliRunner<int>('tool', 'x', logger: _logger(out));
      expect(runner.usage, isNot(contains('completion')));
      expect(runner.commands.keys, ['help']);
    });
  });

  group('completion <shell>', () {
    Future<String> run(List<String> args,
        {Map<String, String> env = const {}, String exe = 'notes'}) async {
      final runner = CliRunner<int>(exe, 'x', logger: _logger(out, env: env))
        ..addCommand(_Sub('go'));
      await runner.run(args);
      return out.text;
    }

    test('prints a script bound to the executable name', () async {
      final bash = await run(['completion', 'bash']);
      expect(bash, contains("'notes' __complete \"\${words[@]}\""));
      expect(bash,
          endsWith("complete -o default -F _notes_complete -- 'notes'\n"));
      out.clear();
      expect(await run(['completion', 'zsh']), startsWith('#compdef notes\n'));
      out.clear();
      expect(await run(['completion', 'fish']),
          contains("complete -c 'notes' -f -a '(__notes_complete)'"));
    });

    test('a name that is not a shell word is made safe for function names',
        () async {
      final script = await run(['completion', 'bash'], exe: 'my-tool.v2');
      expect(script, contains('_my_tool_v2_complete() {'));
      expect(script, contains('my-tool.v2 __complete'));
    });

    test('with no shell it uses \$SHELL', () async {
      expect(await run(['completion'], env: {'SHELL': '/usr/bin/fish'}),
          startsWith('# fish completion for notes.'));
    });

    test('usage errors: no shell, an unknown shell, too many words', () async {
      for (final (args, message) in [
        (['completion'], 'Name a shell: bash, zsh or fish. \$SHELL is "".'),
        (['completion', 'tcsh'], 'Unknown shell "tcsh".'),
        (['completion', 'bash', 'zsh'], 'Too many arguments.'),
        (['completion', 'install', 'bash', 'x'], 'Too many arguments.'),
      ]) {
        await expectLater(
            run(args, env: {}),
            throwsA(isA<UsageException>()
                .having((e) => e.message, 'message', startsWith(message))));
      }
    });

    test('global --help prints completion help without running it', () async {
      final help = await run(['--help', 'completion', 'bash']);
      expect(help, contains('notes completion install|uninstall'));
      expect(help, isNot(contains('_notes_complete()')));
    });

    test('--help prints its help', () async {
      final help = await run(['completion', '--help']);
      expect(
          help, contains('notes completion install|uninstall [bash|zsh|fish]'));
      expect(help, contains('source <(notes completion zsh)'));
    });
  });

  group('completion install and uninstall', () {
    late io.Directory home;
    late CaptureSink err;
    setUp(() {
      home = io.Directory.systemTemp.createTempSync('completion_home');
      addTearDown(() => home.deleteSync(recursive: true));
      err = CaptureSink();
    });

    /// Every file under HOME, with its contents.
    Map<String, String> files() => {
          for (final entity in home.listSync(recursive: true))
            if (entity is io.File)
              entity.path.substring(home.path.length):
                  entity.readAsStringSync(),
        };

    Set<String> dirs() => {
          for (final entity in home.listSync(recursive: true))
            if (entity is io.Directory) entity.path.substring(home.path.length),
        };

    CliRunner<int> runner(
            {Map<String, String> env = const {}, bool plain = true}) =>
        CliRunner<int>('notes', 'x',
            logger: _logger(out, err: err, env: {
              'HOME': home.path,
              if (plain) 'ACCESSIBLE': '1',
              ...env,
            }))
          ..addCommand(_Sub('go'));

    Future<String> script(String shell) async {
      final out = CaptureSink();
      await (CliRunner<int>('notes', 'x', logger: _logger(out))
            ..addCommand(_Sub('go')))
          .run(['completion', shell]);
      return out.text;
    }

    test('bash: XDG data dir, twice changes nothing, uninstall removes it',
        () async {
      await runner().run(['completion', 'install', 'bash']);
      const path = '/.local/share/bash-completion/completions/notes';
      expect(files(), {path: await script('bash')});
      expect(out.text, contains('Installed ${home.path}$path'));
      expect(out.text, contains('bash-completion'));

      out.clear();
      await runner().run(['completion', 'install', 'bash']);
      expect(out.text, contains('Already installed'));
      expect(files(), {path: await script('bash')});

      final before = dirs();
      await runner().run(['completion', 'uninstall', 'bash']);
      expect(files(), isEmpty);
      expect(dirs(), before, reason: 'shared directories stay');
      out.clear();
      await runner().run(['completion', 'uninstall', 'bash']);
      expect(out.text, contains('Nothing to remove for bash.'));
    });

    test('bash and fish follow XDG_DATA_HOME and XDG_CONFIG_HOME', () async {
      final env = {
        'XDG_DATA_HOME': '${home.path}/data',
        'XDG_CONFIG_HOME': '${home.path}/config',
      };
      await runner(env: env).run(['completion', 'install', 'bash']);
      await runner(env: env).run(['completion', 'install', 'fish']);
      expect(files().keys, {
        '/data/bash-completion/completions/notes',
        '/config/fish/completions/notes.fish',
      });
      expect(
          files()['/config/fish/completions/notes.fish'], await script('fish'));
    });

    test('a relative XDG directory is ignored', () async {
      await runner(env: {'XDG_CONFIG_HOME': 'rel'})
          .run(['completion', 'install', 'fish']);
      expect(files().keys, {'/.config/fish/completions/notes.fish'});
    });

    test('fish uses \$SHELL when no shell is named', () async {
      await runner(env: {'SHELL': '/opt/bin/fish'})
          .run(['completion', 'install']);
      expect(files().keys, {'/.config/fish/completions/notes.fish'});
      await runner(env: {'SHELL': '/opt/bin/fish'})
          .run(['completion', 'uninstall']);
      expect(files(), isEmpty);
    });

    const rc = '# my zshrc\nexport EDITOR=vim\n';
    const fn = '/.local/share/notes/zsh/_notes';

    void writeRc(String text) =>
        io.File('${home.path}/.zshrc').writeAsStringSync(text);
    String readRc() => io.File('${home.path}/.zshrc').readAsStringSync();

    test(
        'zsh --yes: the function file and one rc block; uninstall restores '
        'the rc byte for byte', () async {
      writeRc(rc);
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      expect(files()[fn], await script('zsh'));
      final installed = readRc();
      expect(installed, startsWith(rc));
      expect(installed, endsWith('# <<< notes completion <<<\n'));
      expect(installed,
          contains("fpath=('${home.path}/.local/share/notes/zsh' \$fpath)"));
      expect(out.text, contains('exec zsh'));

      await runner(plain: false).run(['completion', 'install', 'zsh', '-y']);
      expect(readRc(), installed, reason: 'the block is added once');

      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), rc);
      expect(files().keys, {'/.zshrc'});
      expect(dirs(), {'/.local', '/.local/share'},
          reason: 'the directories install made are gone');
    });

    for (final original in ['', 'no newline at the end']) {
      test('zsh uninstall restores "$original" exactly', () async {
        writeRc(original);
        await runner(plain: false)
            .run(['completion', 'install', 'zsh', '--yes']);
        expect(readRc(), contains('# >>> notes completion >>>'));
        await runner(plain: false)
            .run(['completion', 'uninstall', 'zsh', '--yes']);
        expect(readRc(), original);
      });
    }

    test('zsh preserves CRLF content byte for byte', () async {
      const original = '# config\r\nexport EDITOR=vim\r\n';
      writeRc(original);
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), original);
    });

    test('uninstall recognizes a completion block converted to CRLF', () async {
      const original = '# config\r\nexport EDITOR=vim\r\n';
      writeRc(original);
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      final installed = readRc();
      writeRc(original +
          installed.substring(original.length).replaceAll('\n', '\r\n'));
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), original);
    });

    test('text added after the block keeps its own line', () async {
      writeRc('no trailing newline');
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      io.File('${home.path}/.zshrc')
          .writeAsStringSync('alias x=y\n', mode: io.FileMode.append);
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), 'no trailing newline\nalias x=y\n');
    });

    test('editing an rc block does not authorize deleting outside it',
        () async {
      writeRc('no trailing newline');
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      writeRc(readRc().replaceFirst('autoload -Uz', '# edited\nautoload -Uz'));
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), 'no trailing newline');
    });

    test('an unmatched nested start never removes surrounding rc text',
        () async {
      const original = '# >>> notes completion >>>\n'
          'keep this\n'
          '# >>> notes completion >>>\n'
          'also keep this\n'
          '# <<< notes completion <<<\n'
          'after\n';
      writeRc(original);
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), original);
    });

    test('zsh follows ZDOTDIR and creates a missing .zshrc', () async {
      await runner(plain: false, env: {'ZDOTDIR': '${home.path}/zdot'})
          .run(['completion', 'install', 'zsh', '--yes']);
      expect(files().keys, {fn, '/zdot/.zshrc'});
    });

    test('zsh asks first; a declined confirm writes nothing', () async {
      writeRc(rc);
      final t = TuiTester.run(
          () => runner(plain: false).run(['completion', 'install', 'zsh']));
      addTearDown(t.dispose);
      await t.waitFor((s) => s.contains('[y/N]'));
      expect(
          out.text, contains('This adds these lines to ${home.path}/.zshrc:'));
      expect(out.text, contains('# >>> notes completion >>>'));
      await t.press('n');
      await t.done();
      expect(out.text, contains('Nothing changed.'));
      expect(files(), {'/.zshrc': rc});
    });

    test('zsh asks first; yes installs, and uninstall asks too', () async {
      writeRc(rc);
      var t = TuiTester.run(
          () => runner(plain: false).run(['completion', 'install', 'zsh']));
      addTearDown(t.dispose);
      await t.waitFor((s) => s.contains('[y/N]'));
      await t.press('y');
      await t.done();
      expect(files().keys, {'/.zshrc', fn});

      out.clear();
      t = TuiTester.run(
          () => runner(plain: false).run(['completion', 'uninstall', 'zsh']));
      addTearDown(t.dispose);
      await t.waitFor((s) => s.contains('[y/N]'));
      expect(out.text, contains('This removes these lines'));
      await t.press('n');
      await t.done();
      expect(out.text, contains('Nothing changed.'));
      expect(files().keys, {'/.zshrc', fn});
    });

    test('plain mode never edits the rc file; it prints the lines', () async {
      writeRc(rc);
      await runner().run(['completion', 'install', 'zsh', '--yes']);
      expect(files(), {'/.zshrc': rc, fn: await script('zsh')});
      expect(out.text, contains('Add these lines to ${home.path}/.zshrc:'));
      expect(out.text, contains('# >>> notes completion >>>'));

      // With the block added by hand, uninstall says to remove it.
      writeRc(
          rc + RegExp(r'# >>> notes[\s\S]*<<<\n').firstMatch(out.text)![0]!);
      final edited = readRc();
      out.clear();
      await runner().run(['completion', 'uninstall', 'zsh']);
      expect(
          out.text, contains('Remove these lines from ${home.path}/.zshrc:'));
      expect(readRc(), edited);
      expect(files().keys, {'/.zshrc'});
    });

    test('uninstall removes only our block', () async {
      writeRc('a\n# >>> other completion >>>\nx\n# <<< other completion <<<\n');
      final before = readRc();
      await runner(plain: false).run(['completion', 'install', 'zsh', '--yes']);
      io.File('${home.path}/.zshrc')
          .writeAsStringSync('after\n', mode: io.FileMode.append);
      await runner(plain: false)
          .run(['completion', 'uninstall', 'zsh', '--yes']);
      expect(readRc(), '${before}after\n');
    });

    test('zsh rc markers treat regex and shell metacharacters literally',
        () async {
      for (final exe in [
        "notes.[x]\$';&",
        'notes\n# <<< notes completion <<<\r'
      ]) {
        final custom = CliRunner<int>(exe, 'x',
            logger: _logger(out, env: {'HOME': home.path}))
          ..addCommand(_Sub('go'));
        const original = '# >>> notes.x completion >>>\n'
            'keep\n# <<< notes.x completion <<<\n';
        writeRc(original);
        await custom.run(['completion', 'install', 'zsh', '--yes']);
        // The shell test checks the scripts; here only when zsh is there.
        if (io.Process.runSync('sh', ['-c', 'command -v zsh']).exitCode == 0) {
          final syntax =
              await io.Process.run('zsh', ['-n', '${home.path}/.zshrc']);
          expect(syntax.exitCode, 0, reason: '${syntax.stderr}');
        }
        await custom.run(['completion', 'uninstall', 'zsh', '--yes']);
        expect(readRc(), original);
      }
    });

    test('no HOME is an error', () async {
      final runner = CliRunner<int>('notes', 'x',
          logger: _logger(out, err: err, env: const {}))
        ..addCommand(_Sub('go'));
      await expectLater(runner.runAndExit(['completion', 'install', 'bash']),
          throwsA(isA<_Exit>().having((e) => e.code, 'code', 70)));
      expect(err.text, contains('HOME is not set.'));
    });
  }, testOn: '!windows');
}

final class _Throws extends CliCommand<int> {
  @override
  String get name => 'throws';
  @override
  String get description => 'Its hook throws.';
  @override
  Iterable<String> completeValue(String option, String partial) =>
      throw StateError('boom');
  @override
  int run() => 0;
}

final class _ResultsProbe extends CliCommand<int> {
  _ResultsProbe() {
    argParser.addOption('value');
  }
  @override
  String get name => 'probe';
  @override
  String get description => 'Probe parsed results.';
  @override
  Iterable<String> completeValue(String option, String partial) =>
      [argResults == null && globalResults == null ? 'clean' : 'stale'];
  @override
  int run() => 0;
}

final class _PlainHelp extends Command<int> {
  _PlainHelp() {
    addSubcommand(_Sub('topic'));
  }
  @override
  String get name => 'help';
  @override
  String get description => 'User help.';
}

final class _RemoteWithHelp extends CliCommand<int> {
  _RemoteWithHelp() {
    addSubcommand(_PlainHelp());
  }
  @override
  String get name => 'custom';
  @override
  String get description => 'Custom commands.';
}

final class _NeverRun extends CliCommand<int> {
  _NeverRun() {
    argParser.addOption('value');
  }
  int runs = 0;
  @override
  String get name => 'probe';
  @override
  String get description => 'Must not execute.';
  @override
  int run() {
    runs++;
    throw StateError('completion executed a command');
  }
}

final class _StyledCompletion extends CliCommand<int> {
  _StyledCompletion() {
    argParser.addOption('value',
        allowed: ['safe'],
        allowedHelp: {'safe': '\u001b[31mRed description\u001b[0m'});
  }
  @override
  String get name => 'styled';
  @override
  String get description => 'Styled values.';
  @override
  Iterable<String> completeValue(String option, String partial) =>
      ['safe\t\u001b[32mHook description\u001b[0m'];
  @override
  int run() => 0;
}
