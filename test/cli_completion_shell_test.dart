// The generated completion scripts, run in real shells against the notes
// example compiled to `notes`. bash always runs; zsh and fish tests skip
// when the shell is not installed (CI installs both on Linux).
@TestOn('!windows')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

bool _has(String shell) =>
    Process.runSync('sh', ['-c', 'command -v $shell']).exitCode == 0;

final _zsh = _has('zsh') ? null : 'zsh is not installed';
final _fish = _has('fish') ? null : 'fish is not installed';

/// Types a line and Tab in an interactive zsh under zpty, then prints every
/// match compsys adds, one per line. It types only once the prompt shows:
/// zle inserts a Tab that arrives as typeahead instead of completing.
const _zshDriver = r'''
zmodload zsh/zpty
zpty z zsh -f -i
zpty -w z 'autoload -Uz compinit; compinit -u -D'
zpty -w z "source ${(q)1}"
zpty -w z 'zstyle ":completion:*" menu no'
zpty -w z 'compadd() { local -a __m; builtin compadd -O __m "$@"; local m; for m in $__m; do print -r -- "<<M>>$m<<E>>"; done; builtin compadd "$@"; }'
zpty -w z 'bindkey "^I" complete-word; RPS1=; PS1="<<PRO""MPT>>"'
zpty -r z line '*<<PROMPT>>*' >/dev/null
zpty -n -w z "$2"$'\t'
zpty -w z $'\x15print -r -- "<<DO""NE>>"'
out=
while zpty -r z line; do
  out+=$line
  [[ $out == *'<<DONE>>'* ]] && break
done
zpty -d z
print -r -- "$out" | grep -o '<<M>>[^<]*<<E>>' | sed -e 's/^<<M>>//' -e 's/<<E>>$//'
''';

void main() {
  late Directory tmp;
  late Map<String, String> env;
  late String home;

  Future<ProcessResult> run(String exe, List<String> args) => Process.run(
        exe,
        args,
        environment: env,
        includeParentEnvironment: false,
      ).timeout(const Duration(seconds: 60));

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('completion_shell');
    final bin = Directory('${tmp.path}/bin')..createSync();
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      'example/cli_app/notes.dart',
      '-o',
      '${bin.path}/notes',
    ]);
    expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
    home = '${tmp.path}/home';
    Directory('$home/files').createSync(recursive: true);
    File('$home/files/apple.txt').writeAsStringSync('');
    File('$home/.notes.json').writeAsStringSync(jsonEncode([
      {'text': 'Buy milk', 'priority': 'high', 'done': false},
      {'text': 'Call Sam', 'priority': 'low', 'done': true},
      {'text': 'Ship it: v2', 'priority': 'low', 'done': false},
    ]));
    env = {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'HOME': home,
      'TERM': 'dumb',
    };
    for (final shell in ['bash', 'zsh', 'fish']) {
      final script = await run('notes', ['completion', shell]);
      expect(script.exitCode, 0, reason: '${script.stderr}');
      File('${tmp.path}/notes.$shell').writeAsStringSync('${script.stdout}');
    }
    File('${tmp.path}/driver.zsh').writeAsStringSync(_zshDriver);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  String script(String shell) => '${tmp.path}/notes.$shell';

  group('syntax', () {
    test('bash -n', () async {
      expect((await run('bash', ['-n', script('bash')])).exitCode, 0);
    });
    test('zsh -n', () async {
      expect((await run('zsh', ['-n', script('zsh')])).exitCode, 0);
    }, skip: _zsh);
    test('fish -n', () async {
      expect((await run('fish', ['-n', script('fish')])).exitCode, 0);
    }, skip: _fish);
  });

  test('bash: COMP_WORDS in, COMPREPLY out', () async {
    // Bash splits "--priority=h" into "--priority", "=", "h".
    final cases = {
      "notes ''": 'add|done|list|ls|completion',
      'notes l': 'list|ls',
      'notes add --pri': '--priority',
      "notes add --priority ''": 'low|normal|high',
      "notes add --priority = ''": 'low|normal|high',
      'notes add --priority = h': 'high',
      "notes done ''": '1|3',
      "notes completion ''": 'bash|zsh|fish|install|uninstall',
      "notes add -f ''": '',
    };
    final body = StringBuffer('source ${script('bash')}\n'
        't() { COMP_WORDS=("\$@"); COMP_CWORD=\$((\${#COMP_WORDS[@]} - 1)); '
        'COMPREPLY=(); _notes_complete; local IFS="|"; '
        'echo "\${COMPREPLY[*]}"; }\n');
    for (final words in cases.keys) {
      body.writeln('t $words');
    }
    final result = await run('bash', ['--norc', '--noprofile', '-c', '$body']);
    expect(result.stderr, '');
    expect(const LineSplitter().convert('${result.stdout}'), cases.values);
  });

  group('zsh, through compsys', () {
    Future<Set<String>> tab(String line) async {
      final result = await run(
          'zsh', ['-f', '${tmp.path}/driver.zsh', script('zsh'), line]);
      return const LineSplitter().convert('${result.stdout}').toSet();
    }

    test('commands, flags, allowed values, hook values and files', () async {
      expect(await tab('notes '), {'add', 'done', 'list', 'ls', 'completion'});
      expect(await tab('notes add --p'), {'--priority', '--plain'});
      expect(await tab('notes add --priority '), {'low', 'normal', 'high'});
      expect(await tab('notes add --priority='), {'low', 'normal', 'high'});
      expect(await tab('notes done '), {'1', '3'});
      // _files adds each path segment; the last is the file.
      expect(await tab('notes add -f $home/files/a'), contains('apple.txt'));
    });
  }, skip: _zsh);

  group('fish, through complete -C', () {
    Future<List<String>> tab(String line) async {
      final result = await run('fish', [
        '--no-config',
        '-c',
        'source ${script('fish')}; complete -C "$line"',
      ]);
      expect(result.stderr, '');
      return const LineSplitter().convert('${result.stdout}');
    }

    test('commands, flags, allowed values, hook values and files', () async {
      expect(await tab('notes l'),
          ['list\tList the notes.', 'ls\tList the notes.']);
      // fish sorts the candidates.
      expect(await tab('notes add --priority '),
          ['high\tToday.', 'low\tSome day.', 'normal\tThis week.']);
      expect(await tab('notes add --priority=h'), ['--priority=high\tToday.']);
      expect(await tab('notes done '), ['1\tBuy milk', '3\tShip it: v2']);
      expect(await tab('notes add -f $home/files/a'),
          [startsWith('$home/files/apple.txt')]);
    });
  }, skip: _fish);
}
