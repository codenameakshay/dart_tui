part of 'cli.dart';

/// Cobra's directive bit: do not fall back to file completion.
const _noFileComp = 4;

const _shells = ['bash', 'zsh', 'fish'];

/// Answers `<exe> __complete <words...>`: one candidate per line
/// (`value\tdescription`), then `:<directive>`. The last word is the one
/// being completed. Throws on any problem; the caller prints nothing then.
Future<String> _completions<T>(CliRunner<T> runner, List<String> words) async {
  if (words.isEmpty) words = [''];
  final cur = words.last;
  final parsers = [runner.argParser];
  Map<String, Command<T>> commands = runner.commands;
  Command<T>? command;
  Option? pending;
  var positional = false;
  var dashdash = false;

  // args looks an option up in the command's parser, then its parents'.
  Option? byName(String name) {
    for (final parser in parsers.reversed) {
      if (parser.findByNameOrAlias(name) case final option?) return option;
    }
    return null;
  }

  Option? byAbbr(String abbr) {
    for (final parser in parsers.reversed) {
      if (parser.findByAbbreviation(abbr) case final option?) return option;
    }
    return null;
  }

  for (final word in words.take(words.length - 1)) {
    if (pending != null) {
      pending = null;
    } else if (dashdash || word == '-' || !word.startsWith('-')) {
      final next = positional || dashdash ? null : commands[word];
      if (next != null && next.name == 'help' && next is! CliCommand) {
        // args' help command takes command names: stay at this level.
        continue;
      } else if (next != null) {
        command = next;
        commands = next.subcommands;
        parsers.add(next.argParser);
      } else {
        positional = true;
      }
    } else if (word == '--') {
      dashdash = true;
    } else if (word.startsWith('--')) {
      final option = word.contains('=') ? null : byName(word.substring(2));
      if (option != null && !option.isFlag) pending = option;
    } else {
      // -abc: a value option takes the rest of the word, or the next word.
      for (var i = 1; i < word.length; i++) {
        final option = byAbbr(word[i]);
        if (option != null && !option.isFlag) {
          if (i == word.length - 1) pending = option;
          break;
        }
      }
    }
  }

  final hook = command is CliCommand<T> ? command : null;
  final out = <(String, String?)>[];

  Future<int> values(Option option, String partial, String prefix) async {
    if (option.allowed case final allowed?) {
      for (final value in allowed) {
        out.add(('$prefix$value', option.allowedHelp?[value]));
      }
      return _noFileComp;
    }
    final found = await hook?.completeValue(option.name, partial) ?? const [];
    for (final entry in found) {
      final (value, help) = _split(entry);
      out.add(('$prefix$value', help));
    }
    return found.isEmpty ? 0 : _noFileComp;
  }

  int directive;
  if (pending != null) {
    directive = await values(pending, cur, '');
  } else if (!dashdash && cur.startsWith('--') && cur.contains('=')) {
    final eq = cur.indexOf('=');
    final option = byName(cur.substring(2, eq));
    directive = option == null || option.isFlag
        ? _noFileComp
        : await values(option, cur.substring(eq + 1), cur.substring(0, eq + 1));
  } else if (!dashdash && cur.startsWith('-')) {
    final seen = <String>{};
    for (final parser in parsers.reversed) {
      for (final option in parser.options.values) {
        if (option.hide || !seen.add(option.name)) continue;
        final help = option.help?.split('\n').first;
        out.add(('--${option.name}', help));
        if (option.isFlag && option.negatable == true) {
          out.add(('--no-${option.name}', help));
        }
        if (option.abbr != null) out.add(('-${option.abbr}', help));
      }
    }
    directive = _noFileComp;
  } else if (!positional && !dashdash && commands.isNotEmpty) {
    for (final MapEntry(key: name, value: sub) in commands.entries) {
      if (!sub.hidden) out.add((name, sub.summary));
    }
    directive = _noFileComp;
  } else {
    final found = await hook?.completeValue('', cur) ?? const [];
    out.addAll(found.map(_split));
    final files = command != null &&
        command.subcommands.isEmpty &&
        command.takesArguments;
    directive = found.isEmpty && files ? 0 : _noFileComp;
  }

  final lines = StringBuffer();
  for (final (value, help) in out) {
    if (!value.startsWith(cur)) continue;
    lines.write(_oneLine(value));
    if (help != null && help.isNotEmpty) lines.write('\t${_oneLine(help)}');
    lines.writeln();
  }
  lines.writeln(':$directive');
  return '$lines';
}

(String, String?) _split(String entry) {
  final tab = entry.indexOf('\t');
  return tab < 0
      ? (entry, null)
      : (entry.substring(0, tab), entry.substring(tab + 1));
}

String _oneLine(String text) => text.replaceAll(RegExp(r'[\t\r\n]+'), ' ');

/// `completion [bash|zsh|fish]` and `completion install|uninstall [shell]`.
final class _CompletionCommand<T> extends CliCommand<T> {
  _CompletionCommand() {
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Edit your .zshrc without asking (zsh install and uninstall).',
    );
  }

  @override
  String get name => 'completion';

  String get _exe => runner!.executableName;

  @override
  String get description => 'Set up shell completion.\n\n'
      'Prints, installs or uninstalls the script for bash, zsh or fish. With no shell named, it uses \$SHELL. '
      'Only the zsh install edits a file of yours (.zshrc), and it asks '
      'first.';

  @override
  String get invocation => '$_exe completion [bash|zsh|fish]\n'
      '$_exe completion install|uninstall [bash|zsh|fish]';

  @override
  List<String> get examples => [
        'source <($_exe completion zsh)',
        '$_exe completion install',
      ];

  @override
  Iterable<String> completeValue(String option, String partial) =>
      option.isEmpty ? [..._shells, 'install', 'uninstall'] : const [];

  @override
  Null run() => null; // coverage:ignore-line

  /// Run by [CliRunner.runCommand].
  Future<void> _run(ArgResults results) async {
    final rest = results.rest;
    final action =
        rest.isNotEmpty && const {'install', 'uninstall'}.contains(rest.first)
            ? rest.first
            : null;
    final args = action == null ? rest : rest.skip(1).toList();
    if (args.length > 1) usageException('Too many arguments.');
    final env = logger._env;
    final shell = args.isNotEmpty
        ? args.single
        : _shells
            .where((s) => (env['SHELL'] ?? '').split('/').last == s)
            .firstOrNull;
    if (shell == null) {
      usageException(
        'Name a shell: bash, zsh or fish. '
        '\$SHELL is "${env['SHELL'] ?? ''}".',
      );
    }
    if (!_shells.contains(shell)) {
      usageException('Unknown shell "$shell". Use bash, zsh or fish.');
    }
    final script = _script(shell, _exe);
    switch (action) {
      case null:
        logger.write(script);
      case 'install':
        await _Installer(this, shell, results.flag('yes')).install(script);
      default:
        await _Installer(this, shell, results.flag('yes')).uninstall();
    }
  }
}

/// Where the scripts go, and the zsh rc block. Paths come from the logger's
/// environment (HOME, XDG_DATA_HOME, XDG_CONFIG_HOME, ZDOTDIR), so tests
/// point them at a temporary directory.
final class _Installer<T> {
  _Installer(this.command, this.shell, this._yes);

  final _CompletionCommand<T> command;
  final String shell;
  final bool _yes;

  Logger get _log => command.logger;
  String get _exe => command._exe;

  String _env(String name) => _log._env[name] ?? '';

  String get _home {
    final home = _env('HOME');
    if (home.isEmpty) throw StateError('HOME is not set.');
    return home;
  }

  /// An XDG directory: the variable when it is an absolute path, else
  /// [fallback] under HOME.
  String _xdg(String name, String fallback) {
    final value = _env(name);
    return value.startsWith('/') ? value : '$_home/$fallback';
  }

  String get _dataHome => _xdg('XDG_DATA_HOME', '.local/share');

  /// The directory install creates for zsh, and owns.
  String get _zshDir => '$_dataHome/$_exe/zsh';

  String get _file => switch (shell) {
        'bash' => '$_dataHome/bash-completion/completions/$_exe',
        'fish' =>
          '${_xdg('XDG_CONFIG_HOME', '.config')}/fish/completions/$_exe.fish',
        _ => '$_zshDir/_$_exe',
      };

  String get _rc =>
      '${_env('ZDOTDIR').isEmpty ? _home : _env('ZDOTDIR')}/.zshrc';

  String get _start => '# >>> $_exe completion >>>';
  String get _end => '# <<< $_exe completion <<<';

  /// Marks a block whose newline before it was added by install, because
  /// the file did not end with one. Uninstall removes that newline too.
  static const _addedNewline = ' (and the newline before it)';

  String get _block => '$_start\n'
      '# Added by "$_exe completion install". '
      '"$_exe completion uninstall" removes it.\n'
      'fpath=("$_zshDir" \$fpath)\n'
      'if (( \$+functions[compdef] )); then\n'
      '  autoload -Uz _$_exe && compdef _$_exe $_exe\n'
      'else\n'
      '  autoload -Uz compinit && compinit\n'
      'fi\n'
      '$_end\n';

  RegExpMatch? _findBlock(String text) => RegExp(
        '^${RegExp.escape(_start)}(.*)\\n[\\s\\S]*?^${RegExp.escape(_end)}\$\\n?',
        multiLine: true,
      ).firstMatch(text);

  String _read(String path) {
    final file = io.File(path);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  /// Shows [lines] for [_rc] and asks before an edit. False in plain mode,
  /// where it prints what to change instead.
  Future<bool> _mayEdit(String verb, String lines) async {
    if (_log._plain) {
      _log.info('$verb these lines ${verb == 'Add' ? 'to' : 'from'} $_rc:');
      _log.write('\n$lines\n');
      return false;
    }
    if (_yes) return true;
    _log.info(
      '${verb == 'Add' ? 'This adds' : 'This removes'} these lines '
      '${verb == 'Add' ? 'to' : 'from'} $_rc:',
    );
    _log.write('\n$lines\n');
    return _log.confirm('Edit $_rc?');
  }

  Future<void> install(String script) async {
    final file = _file;
    if (shell == 'zsh') {
      final rc = _read(_rc);
      if (_findBlock(rc) == null) {
        final edit = await _mayEdit('Add', _block);
        if (!edit && !_log._plain) {
          _log.info('Nothing changed.');
          return;
        }
        _write(file, script);
        if (edit) {
          final needsNewline = rc.isNotEmpty && !rc.endsWith('\n');
          final block = needsNewline
              ? '\n${_block.replaceFirst(_start, '$_start$_addedNewline')}'
              : _block;
          io.File(_rc)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('$rc$block');
          _log.success('Added the completion block to $_rc');
        }
      } else {
        _write(file, script);
      }
      _log.info('Next: run "exec zsh" to load it.');
      return;
    }
    _write(file, script);
    _log.info(
      shell == 'bash'
          ? 'Next: open a new shell. Bash loads it through the bash-completion '
              'package (version 2 or later).'
          : 'Next: open a new shell.',
    );
  }

  void _write(String path, String script) {
    final file = io.File(path);
    if (file.existsSync() && file.readAsStringSync() == script) {
      _log.info('Already installed: $path');
      return;
    }
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(script);
    _log.success('Installed $path');
  }

  Future<void> uninstall() async {
    var changed = false;
    if (shell == 'zsh') {
      final rc = _read(_rc);
      if (_findBlock(rc) case final block?) {
        final edit = await _mayEdit('Remove', block[0]!.trimRight());
        if (!edit && !_log._plain) {
          _log.info('Nothing changed.');
          return;
        }
        changed = true;
        if (edit) {
          var start = block.start;
          if (block[1] == _addedNewline && start > 0 && rc[start - 1] == '\n') {
            start--;
          }
          io.File(_rc).writeAsStringSync(rc.replaceRange(start, block.end, ''));
          _log.success('Removed the completion block from $_rc');
        }
      }
    }
    final file = io.File(_file);
    if (file.existsSync()) {
      file.deleteSync();
      _log.success('Removed ${file.path}');
      changed = true;
      if (shell == 'zsh') {
        // Directories install created; kept when something else is in them.
        for (final dir in [
          io.Directory(_zshDir),
          io.Directory(_zshDir).parent,
        ]) {
          if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
        }
      }
    }
    if (!changed) _log.info('Nothing to remove for $shell.');
  }
}

/// The completion script for [shell], bound to [exe].
String _script(String shell, String exe) {
  final id = exe.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final template = switch (shell) {
    'bash' => _bashScript,
    'zsh' => _zshScript,
    _ => _fishScript,
  };
  return template.replaceAll('{{exe}}', exe).replaceAll('{{id}}', id);
}

const _bashScript = r'''
# bash completion for {{exe}}. Generated by "{{exe}} completion bash".
# Each Tab runs "{{exe}} __complete <words>", so it never goes stale.
_{{id}}_complete() {
  local seps='' i w n joined=0 out last directive line cur prefix=''
  local -a words=()
  [[ $COMP_WORDBREAKS == *=* ]] && seps+='='
  [[ $COMP_WORDBREAKS == *:* ]] && seps+=':'
  # Bash splits "--opt=value" at "=" (and "a:b" at ":"); join them again.
  for ((i = 1; i <= COMP_CWORD; i++)); do
    w=${COMP_WORDS[i]}
    n=${#words[@]}
    if ((n > 0)) && [[ -n $seps ]] && { ((joined)) || [[ $w == [$seps] ]]; }; then
      words[n-1]+=$w
      if [[ $w == [$seps] ]]; then joined=1; else joined=0; fi
    else
      words+=("$w")
      joined=0
    fi
  done
  cur=${words[${#words[@]}-1]}
  # Readline replaces only the text after the last break character.
  if [[ -n $seps && $cur == *[$seps]* ]]; then
    prefix=${cur%"${cur##*[$seps]}"}
  fi
  out=$({{exe}} __complete "${words[@]}" 2>/dev/null) || return 0
  last=${out##*$'\n'}
  [[ $last == :* ]] || return 0
  directive=${last#:}
  if [[ $out == *$'\n'* ]]; then out=${out%$'\n'*}; else out=''; fi
  COMPREPLY=()
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    line=${line%%$'\t'*}
    COMPREPLY+=("${line#"$prefix"}")
  done <<< "$out"
  if ((directive & 4)); then
    compopt +o default 2>/dev/null
  fi
  return 0
}
complete -o default -F _{{id}}_complete {{exe}}
''';

const _zshScript = r'''
#compdef {{exe}}
# zsh completion for {{exe}}. Generated by "{{exe}} completion zsh".
# Each Tab runs "{{exe}} __complete <words>", so it never goes stale.
_{{id}}() {
  local out directive line value desc eq=0
  local -a lines candidates
  out=$({{exe}} __complete "${(@)words[2,CURRENT]}" 2>/dev/null) || return 1
  lines=("${(@f)out}")
  directive=${lines[-1]}
  [[ $directive == :<-> ]] || return 1
  directive=${directive#:}
  # Complete "--opt=value" after the "=".
  if [[ $PREFIX == -*=* ]] && compset -P '*='; then eq=1; fi
  for line in "${(@)lines[1,-2]}"; do
    [[ -n $line ]] || continue
    value=${line%%$'\t'*}
    desc=
    [[ $line == *$'\t'* ]] && desc=${line#*$'\t'}
    ((eq)) && value=${value#*=}
    candidates+=("${value//:/\\:}${desc:+:$desc}")
  done
  if (( $#candidates )); then
    _describe -t values '{{exe}}' candidates
  elif (( ! (directive & 4) )); then
    _files
  fi
}
if [[ $funcstack[1] == _{{id}} ]]; then
  _{{id}} "$@"
else
  compdef _{{id}} {{exe}}
fi
''';

const _fishScript = r'''
# fish completion for {{exe}}. Generated by "{{exe}} completion fish".
# Each Tab runs "{{exe}} __complete <words>", so it never goes stale.
function __{{id}}_complete
    set -l args (commandline -opc)
    set -e args[1]
    set -l out ({{exe}} __complete $args (commandline -ct) 2>/dev/null)
    or return
    set -q out[1]; or return
    string match -qr '^:[0-9]+$' -- $out[-1]; or return
    set -l directive (string sub -s 2 -- $out[-1])
    set -e out[-1]
    if set -q out[1]
        printf '%s\n' $out
    else if test (math "floor($directive / 4) % 2") -eq 0
        __fish_complete_path (commandline -ct)
    end
end
complete -c {{exe}} -e
complete -c {{exe}} -f -a '(__{{id}}_complete)'
''';
