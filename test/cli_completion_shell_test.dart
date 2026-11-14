// The generated completion scripts, run in real shells against the notes
// example compiled to `notes`. bash always runs; zsh and fish tests skip
// when the shell is not installed (CI installs both on Linux).
@TestOn('!windows')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

bool _has(String shell) =>
    Process.runSync('sh', ['-c', 'command -v $shell']).exitCode == 0;

/// The readline driver needs `bind -x` with READLINE_LINE: bash 4 or later.
final _readline = !_has('python3')
    ? 'python3 is not installed'
    : Process.runSync('bash', ['-c', '((BASH_VERSINFO[0] >= 4))']).exitCode == 0
        ? null
        : 'bash 3 has no READLINE_LINE for bind -x';

final _zsh = _has('zsh') ? null : 'zsh is not installed';
final _fish = _has('fish') ? null : 'fish is not installed';

const _bashDriver = r'''
import json, os, pty, re, select, shlex, subprocess, sys, time
master, slave = pty.openpty()
process = subprocess.Popen(['bash', '--norc', '--noprofile', '-i'],
    stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
def until(marker):
    output = b''
    deadline = time.monotonic() + 10
    while marker not in output:
        if time.monotonic() > deadline:
            raise RuntimeError(repr(output))
        if select.select([master], [], [], .1)[0]:
            output += os.read(master, 65536)
    return output
try:
    os.write(master, ('source ' + shlex.quote(sys.argv[1]) +
        '; _capture() { printf "\\n<<LINE>>%s<<END>>\\n" "$READLINE_LINE"; }; '
        'bind -x \'"\\C-x":_capture\'; PS1="<<REA""DY>>"\n').encode())
    until(b'<<READY>>')
    os.write(master, sys.argv[2].encode() + b'\t\x18')
    output = until(b'<<END>>').decode()
    print(json.dumps(re.search(r'<<LINE>>(.*?)<<END>>', output, re.S).group(1)))
finally:
    process.kill()
    process.wait()
    os.close(master)
''';

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

class _FixtureCommand extends CliCommand<int> {
  @override
  String get name => 'fixture';
  @override
  String get description => 'Test fixture.';
}

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
      // A full path: macOS looks the name up in the parent's PATH.
      final script = await run('${bin.path}/notes', ['completion', shell]);
      expect(script.exitCode, 0, reason: '${script.stderr}');
      File('${tmp.path}/notes.$shell').writeAsStringSync('${script.stdout}');
    }
    File('${tmp.path}/driver.zsh').writeAsStringSync(_zshDriver);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  String script(String shell) => '${tmp.path}/notes.$shell';

  Future<String> generate(String shell, String exe) async {
    final out = CaptureSink();
    final runner = CliRunner<int>(exe, 'test',
        logger: Logger(stdout: out, stderr: CaptureSink(), environment: {}))
      ..addCommand(_FixtureCommand());
    await runner.run(['completion', shell]);
    final path = '${tmp.path}/fixture.$shell';
    File(path).writeAsStringSync(out.text);
    return path;
  }

  String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  group('literal executable names', () {
    for (final shell in ['bash', 'zsh', 'fish']) {
      test(shell, () async {
        const exe = r"odd tool';$name[1]\tail{{id}}";
        final executable = File('${tmp.path}/bin/$exe');
        executable.writeAsStringSync("#!/bin/sh\nprintf 'hello\\n:4\\n'\n");
        expect(
            (await Process.run('chmod', ['+x', executable.path])).exitCode, 0);
        final path = await generate(shell, exe);
        final syntax = await run(shell, ['-n', path]);
        expect(syntax.exitCode, 0, reason: '${syntax.stderr}');
        final id = exe.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
        final body = switch (shell) {
          'bash' => 'source ${quote(path)}; COMP_WORDS=(${quote(exe)} ""); '
              'COMP_CWORD=1; _${id}_complete; printf "%s\\n" "\${COMPREPLY[@]}"',
          'zsh' => 'autoload -Uz compinit; compinit -u -D; '
              'source ${quote(path)}; words=(${quote(exe)} ""); CURRENT=2; '
              '_describe() { print -r -- "\${candidates[@]}"; }; _$id',
          _ => 'source ${quote(path)}; '
              'function commandline; end; __${id}_complete',
        };
        final fishExe = exe.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
        env['COMPLETE_LINE'] = "'$fishExe' ";
        final result = await run(shell, ['-c', body]);
        expect(result.stderr, '');
        expect('${result.stdout}'.trim(), 'hello');
      }, skip: shell == 'zsh' ? _zsh : (shell == 'fish' ? _fish : null));
    }
  });

  Future<void> response(String text) async {
    final output = File('${tmp.path}/response')..writeAsStringSync(text);
    final executable = File('${tmp.path}/bin/probe');
    executable.writeAsStringSync('#!/bin/sh\n'
        'printf "<%s>\\n" "\$@" > ${quote('${tmp.path}/arguments')}\n'
        'cat ${quote(output.path)}\n');
    expect((await Process.run('chmod', ['+x', executable.path])).exitCode, 0);
  }

  test('zsh: installed autoload function handles executable punctuation',
      () async {
    const exe = 'my-tool.v2';
    final executable = File('${tmp.path}/bin/$exe');
    executable.writeAsStringSync("#!/bin/sh\nprintf 'hello\\n:4\\n'\n");
    expect((await Process.run('chmod', ['+x', executable.path])).exitCode, 0);
    final path = await generate('zsh', exe);
    final dir = Directory('${tmp.path}/autoload')..createSync();
    File(path).copySync('${dir.path}/_$exe');
    final loader = File('${tmp.path}/loader.zsh')
      ..writeAsStringSync('fpath=(${quote(dir.path)} \$fpath)\n'
          'autoload -Uz _$exe\ncompdef _$exe $exe\n');
    final result = await run(
        'zsh', ['-f', '${tmp.path}/driver.zsh', loader.path, '$exe ']);
    expect(const LineSplitter().convert('${result.stdout}').toSet(), {'hello'});
  }, skip: _zsh);

  test('bash: preserve spaces and colon wordbreak prefixes', () async {
    final path = await generate('bash', 'probe');
    await response('--value=alpha beta\tSpace\n--value=a:b\tColon\n:4\n');
    final result = await run('bash', [
      '-c',
      '''
source ${quote(path)}
COMP_WORDBREAKS='=:'
COMP_WORDS=(probe --value = a); COMP_CWORD=3
_probe_complete
printf '<%s>\\n' "\${COMPREPLY[@]}"
printf '%s\\n' '--value=a:b' ':4' > ${quote('${tmp.path}/response')}
COMP_WORDS=(probe --value = a : b); COMP_CWORD=5
_probe_complete
printf '<%s>\\n' "\${COMPREPLY[@]}"
'''
    ]);
    expect(result.stderr, '');
    expect(result.stdout, '<alpha beta>\n<a:b>\n<b>\n');
  });

  test('bash: the file directive leaves files to readline, and does not leak',
      () async {
    final path = await generate('bash', 'probe');
    await response(':0\n');
    final result = await run('bash', [
      '-c',
      '''
source ${quote(path)}
compopt() { return 127; }
cd ${quote('$home/files')}
COMP_WORDS=(probe a); COMP_CWORD=1
_probe_complete
printf '<%s>\\n' "\${COMPREPLY[@]}"
printf ':4\\n' > ${quote('${tmp.path}/response')}
COMPREPLY=(); _probe_complete
printf 'count=%s\\n' "\${#COMPREPLY[@]}"
'''
    ]);
    expect(result.stderr, '');
    expect(result.stdout, '<>\ncount=0\n');
  });

  test('bash: readline inserts literal spaces and quoted colons', () async {
    final path = await generate('bash', 'probe');
    await response('--value=a:b c\tA value\n:4\n');
    for (final line in ['probe --value=a:b', 'probe --value="a:b']) {
      final result = await run('python3', ['-c', _bashDriver, path, line]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
          jsonDecode('${result.stdout}'),
          line.contains('"')
              ? 'probe --value="a:b c" '
              : r'probe --value=a:b\ c ');
    }
  }, skip: _readline);

  test('bash: readline quotes file fallback spaces', () async {
    final path = await generate('bash', 'probe');
    File('$home/files/two words.txt').writeAsStringSync('');
    await response(':0\n');
    final result = await run(
        'python3', ['-c', _bashDriver, path, 'probe $home/files/two']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
        jsonDecode('${result.stdout}'), 'probe $home/files/two\\ words.txt ');
  }, skip: _readline);

  test('bash: malformed output clears earlier candidates', () async {
    final path = await generate('bash', 'probe');
    await response('hello\n:4\n');
    final result = await run('bash', [
      '-c',
      '''
source ${quote(path)}
COMP_WORDS=(probe ''); COMP_CWORD=1
_probe_complete
printf '%s\\n' "\${COMPREPLY[@]}"
printf 'invalid\\n' > ${quote('${tmp.path}/response')}
_probe_complete
printf 'count=%s\\n' "\${#COMPREPLY[@]}"
'''
    ]);
    expect(result.stdout, 'hello\ncount=0\n');
  });

  test('fish: backend receives empty and dequoted current words', () async {
    final path = await generate('fish', 'probe');
    await response(':4\n');
    for (final entry in {
      'probe ': '',
      'probe --value="a b': '--value=a b',
      r'probe --value=a\ b': '--value=a b',
    }.entries) {
      env['COMPLETE_LINE'] = entry.key;
      final result = await run('fish', [
        '--no-config',
        '-c',
        'source ${quote(path)}; complete -C "\$COMPLETE_LINE"'
      ]);
      expect(result.stderr, '');
      expect(File('${tmp.path}/arguments').readAsStringSync(),
          '<__complete>\n<${entry.value}>\n');
    }
  }, skip: _fish);

  for (final shell in ['zsh', 'fish']) {
    test('$shell: literal candidate spaces, colons and backslashes', () async {
      final path = await generate(shell, 'probe');
      await response('alpha beta\tSpace\na:b\tColon\na\\:b\tSlash\n:4\n');
      final result = shell == 'zsh'
          ? await run('zsh', ['-f', '${tmp.path}/driver.zsh', path, 'probe '])
          : await run('fish', [
              '--no-config',
              '-c',
              'source ${quote(path)}; complete -C "probe "'
            ]);
      final lines = const LineSplitter().convert('${result.stdout}').toSet();
      expect(
          lines,
          shell == 'zsh'
              ? unorderedEquals(['alpha beta', 'a:b', r'a\:b'])
              : unorderedEquals(
                  ['alpha beta\tSpace', 'a:b\tColon', 'a\\:b\tSlash']));
    }, skip: shell == 'zsh' ? _zsh : _fish);
  }

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
