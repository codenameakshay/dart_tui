part of 'cli.dart';

typedef _Paint = String Function(Style style, String text);

String _noPaint(Style style, String text) => text;

const _heading = Style(isBold: true);
const _accent = Style(foreground256: 6);
const _errorStyle = Style(foreground256: 9, isBold: true);

/// A [CommandRunner] with styled help, a [Logger] and standard flags.
///
/// It is a drop-in replacement: rename `CommandRunner` to [CliRunner] and
/// `Command` to [CliCommand], and the app runs as before.
///
/// What it adds:
///
/// * [logger], shared by every [CliCommand] as [CliCommand.logger].
/// * Global flags: `-v, --verbose` ([Level.verbose]), `-q, --quiet`
///   ([Level.quiet]), `--[no-]color` (`--no-color` turns colour off,
///   `--color` turns it on even in pipes), `--plain` (the logger's prompts
///   ask plain line questions, see [withPlainMode]), and `--version` when
///   [version] is set. They apply while [run] runs and are restored after.
///   A global flag is not added when the runner's [argParser] or any
///   command's parser already defines an option with the same name (or
///   `no-color` for `--color`); the user's option wins. An abbreviation
///   that is already taken is left out.
/// * Help in the layout of Cobra and gh, wrapped to [usageLineLength]: the
///   description, `Usage:`, commands grouped by [Command.category] in
///   aligned columns, flags with their defaults and allowed values,
///   [CliCommand.examples], and the footer. Colour follows the logger:
///   none in pipes, with `NO_COLOR`, `--no-color` or in plain mode.
/// * [runAndExit], which prints errors and exits with a standard code.
class CliRunner<T> extends CommandRunner<T> {
  /// [usageLineLength] defaults to the terminal width, or 80 without a
  /// terminal. [logger] defaults to a new [Logger].
  CliRunner(
    super.executableName,
    super.description, {
    this.version,
    Logger? logger,
    int? usageLineLength,
    super.suggestionDistanceLimit,
  })  : logger = logger ?? Logger(),
        super(
          usageLineLength: usageLineLength ??
              (io.stdout.hasTerminal ? io.stdout.terminalColumns : 80),
        );

  /// Printed by `--version` as `<executableName> version <version>`. The
  /// flag exists only when this is set.
  final String? version;

  /// The logger every [CliCommand] uses.
  final Logger logger;

  /// The global flags this runner added. Added on first use, so options and
  /// commands added after the constructor are seen by the clash check;
  /// ones added after the first [usage], [parse] or [run] are not.
  late final Set<String> _globals = _addGlobalFlags();

  Set<String> _addGlobalFlags() {
    final taken = <String>{};
    final abbreviations = <String>{};
    void scan(ArgParser parser) {
      for (final option in parser.options.values) {
        if (option.abbr != null) abbreviations.add(option.abbr!);
        taken
          ..add(option.name)
          ..addAll(option.aliases);
      }
    }

    void walk(Iterable<Command<T>> commands) {
      for (final command in commands) {
        scan(command.argParser);
        walk(command.subcommands.values);
      }
    }

    scan(argParser);
    walk(commands.values);

    final added = <String>{};
    void add(String name, String help, {String? abbr, bool negatable = false}) {
      if (taken.contains(name) || (negatable && taken.contains('no-$name'))) {
        return;
      }
      argParser.addFlag(
        name,
        abbr: abbr != null && !abbreviations.contains(abbr) ? abbr : null,
        negatable: negatable,
        defaultsTo: negatable ? null : false,
        help: help,
      );
      added.add(name);
    }

    add('verbose', 'Show all log output, and stack traces on errors.',
        abbr: 'v');
    add('quiet', 'Hide log output. Errors still show.', abbr: 'q');
    add('color', 'Force colour on, even in pipes, or off with --no-color.',
        negatable: true);
    add('plain', 'Ask prompts as plain lines, without the terminal UI.');
    if (version != null) add('version', 'Print the version and exit.');
    return added;
  }

  _Paint get _stdoutPaint => logger._painter(logger._out);

  @override
  String get usage => _runnerHelp(_stdoutPaint, withDescription: true);

  String _runnerHelp(_Paint paint, {required bool withDescription}) {
    _globals;
    return _help(
      paint: paint,
      width: argParser.usageLineLength ?? 80,
      description: withDescription ? description : null,
      invocation: invocation,
      commands: commands,
      commandsTitle: 'Commands',
      flags: [('Flags', argParser, null)],
      hint: 'Run "$executableName help <command>" for more information '
          'about a command.',
      footer: usageFooter,
    );
  }

  String _commandHelp(
    Command<T> command,
    _Paint paint, {
    required bool withDescription,
  }) {
    _globals;
    return _help(
      paint: paint,
      width: argParser.usageLineLength ?? 80,
      description: withDescription ? command.description : null,
      invocation: command.invocation,
      commands: command.subcommands,
      commandsTitle: 'Subcommands',
      flags: [
        ('Flags', command.argParser, null),
        ('Global flags', argParser, 'help'),
      ],
      examples: command is CliCommand<T> ? command.examples : const [],
      footer: command.usageFooter,
    );
  }

  @override
  void printUsage() => logger._emit(logger._out, '$usage\n');

  @override
  Never usageException(String message) => throw _CliUsageException(
        message,
        (paint) => _runnerHelp(paint, withDescription: false),
      );

  @override
  ArgResults parse(Iterable<String> args) {
    _globals;
    return super.parse(args);
  }

  /// Parses [args], applies the global flags and runs the command, as
  /// [CommandRunner.run] does. Errors are thrown, not printed; see
  /// [runAndExit].
  @override
  Future<T?> run(Iterable<String> args) => _scoped(args, runCommand);

  @override
  Future<T?> runCommand(ArgResults topLevelResults) async {
    if (_globals.contains('version') && topLevelResults.flag('version')) {
      logger._emit(logger._out, '$executableName version $version\n');
      return null;
    }
    return super.runCommand(topLevelResults);
  }

  /// Runs [args] like [run], then sets [io.exitCode], flushes [logger] and
  /// its output, and exits.
  ///
  /// Exit codes: the command's result when it is an `int`, else 0; 64 for a
  /// [UsageException], with a one-line error, "did you mean" suggestions and
  /// the command's usage on stderr; 70 for any other exception, with a
  /// one-line error (and the stack trace with `--verbose`) on stderr.
  Future<Never> runAndExit(Iterable<String> args) async {
    int finish(int code) {
      io.exitCode = code;
      logger.flush();
      return code;
    }

    int report(Object error, StackTrace stack) => finish(_report(error, stack));
    int code;
    try {
      code = await _scoped(args, (results) async {
        try {
          final result = await runCommand(results);
          return finish(result is int ? result : 0);
        } catch (error, stack) {
          // Inside the scope, so --no-color and --verbose apply.
          return report(error, stack);
        }
      });
    } catch (error, stack) {
      code = report(error, stack);
    }
    for (final sink in [logger._out, logger._err]) {
      try {
        await sink.flush();
      } catch (_) {}
    }
    logger._exit(code);
  }

  Future<R> _scoped<R>(
    Iterable<String> args,
    Future<R> Function(ArgResults results) body,
  ) async {
    final results = parse(args);
    final level = logger.level;
    final profile = logger._profile;
    final plain = logger._forcePlain;
    final styleProfile = Style.defaultProfile;
    try {
      bool on(String flag) => _globals.contains(flag) && results.flag(flag);
      if (on('quiet')) logger.level = Level.quiet;
      if (on('verbose')) logger.level = Level.verbose;
      if (_globals.contains('color') && results.wasParsed('color')) {
        // --color is FORCE_COLOR=1: at least 16 colours, more when the
        // terminal says so.
        final forced = results.flag('color')
            ? detectColorProfile(
                environment: {...logger._env, 'FORCE_COLOR': '1'})
            : ColorProfile.noColor;
        logger._profile = forced;
        Style.defaultProfile = forced;
      }
      if (on('plain')) logger._forcePlain = true;
      return await body(results);
    } finally {
      logger
        ..level = level
        .._profile = profile
        .._forcePlain = plain;
      Style.defaultProfile = styleProfile;
    }
  }

  /// Prints [error] to stderr and returns its exit code.
  int _report(Object error, StackTrace stack) {
    final paint = logger._painter(logger._err);
    final out = StringBuffer(paint(_errorStyle, 'Error:'));
    if (error is! UsageException) {
      out.writeln(' ${_singleLine('$error')}');
      if (logger.level == Level.verbose) out.writeln('$stack'.trimRight());
      logger._emit(logger._err, '$out');
      return 70;
    }
    // args appends its suggestions to the message; show them as a list.
    const marker = 'Did you mean one of these?';
    final lines = error.message.split('\n');
    final cut = lines.indexOf(marker);
    out.writeln(
        ' ${_singleLine((cut < 0 ? lines : lines.take(cut)).join(' ')).trim()}');
    if (cut >= 0) {
      final names = [
        for (final line in lines.skip(cut + 1))
          if (line.trim().isNotEmpty) line.trim(),
      ];
      out
        ..writeln()
        ..writeln(
            paint(_heading, names.length == 1 ? 'Did you mean this?' : marker));
      for (final name in names) {
        out.writeln('  ${paint(_accent, name)}');
      }
    }
    final usage =
        error is _CliUsageException ? error.render(paint) : error.usage;
    out
      ..writeln()
      ..writeln(usage);
    logger._emit(logger._err, '$out');
    return 64;
  }
}

/// A [Command] for a [CliRunner], with its [logger], styled help and
/// [examples].
abstract class CliCommand<T> extends Command<T> {
  /// The runner's [CliRunner.logger].
  Logger get logger => _cliRunner.logger;

  /// Example invocations, shown under "Examples:" in [usage].
  List<String> get examples => const [];

  CliRunner<T> get _cliRunner {
    final runner = this.runner;
    if (runner is CliRunner<T>) return runner;
    throw StateError('Command "$name" is not added to a CliRunner.');
  }

  @override
  String get usage => _cliRunner._commandHelp(this, _cliRunner._stdoutPaint,
      withDescription: true);

  @override
  void printUsage() => logger._emit(logger._out, '$usage\n');

  @override
  Never usageException(String message) => throw _CliUsageException(
        message,
        (paint) => _cliRunner._commandHelp(this, paint, withDescription: false),
      );
}

/// A [UsageException] that can draw its usage again for another output.
final class _CliUsageException extends UsageException {
  _CliUsageException(String message, this.render)
      : super(message, render(_noPaint));

  final String Function(_Paint paint) render;
}

typedef _Words = List<(String, Style?)>;

_Words _words(String text, [Style? style]) => [
      for (final word in text.split(' '))
        if (word.isNotEmpty) (word, style),
    ];

/// Lays [words] out in lines of at most [width] columns. A word longer
/// than [width] gets a line of its own.
List<String> _wrap(_Words words, int width, _Paint paint) {
  final lines = <String>[];
  var line = StringBuffer();
  var used = 0;
  for (final (word, style) in words) {
    final w = textWidth(word);
    if (used > 0 && used + 1 + w > width) {
      lines.add('$line');
      line = StringBuffer();
      used = 0;
    }
    if (used > 0) {
      line.write(' ');
      used++;
    }
    line.write(style == null ? word : paint(style, word));
    used += w;
  }
  if (used > 0 || lines.isEmpty) lines.add('$line');
  return lines;
}

/// [text] wrapped to [width], keeping its line breaks and the indent of
/// each line, then indented by [indent].
List<String> _paragraph(String text, int width, _Paint paint,
    {int indent = 0}) {
  final out = <String>[];
  for (final line in text.split('\n')) {
    final body = line.trimLeft();
    if (body.isEmpty) {
      out.add('');
      continue;
    }
    final pad = indent + line.length - body.length;
    for (final wrapped in _wrap(_words(body), max(width - pad, 1), paint)) {
      out.add('${' ' * pad}$wrapped');
    }
  }
  return out;
}

/// Rows of `  left   right`, the right column wrapped to [width] and
/// aligned at [column] (default: after the widest left cell). Each entry
/// of a row's right side starts a new line.
List<String> _table(
  List<(String, List<_Words>)> rows,
  int width,
  _Paint paint, {
  int? column,
}) {
  final col =
      column ?? rows.fold<int>(0, (w, row) => max(w, textWidth(row.$1)));
  final stacked = 2 + col + 3 > width - 20;
  final start = stacked ? 4 : 2 + col + 3;
  final out = <String>[];
  for (final (left, right) in rows) {
    final lines = [
      for (final words in right) ..._wrap(words, max(width - start, 1), paint),
    ];
    final cell = '  ${paint(_accent, left)}';
    if (stacked) {
      out.addAll(_paragraph(left, width, paint, indent: 2)
          .map((line) => paint(_accent, line)));
      out.addAll(lines
          .where((line) => line.isNotEmpty)
          .map((line) => '${' ' * start}$line'));
      continue;
    }
    out.add(lines.first.isEmpty
        ? cell
        : '$cell${' ' * (start - 2 - textWidth(left))}${lines.first}');
    for (final line in lines.skip(1)) {
      out.add(line.isEmpty ? '' : '${' ' * start}$line');
    }
  }
  return out;
}

const _dim = Style(foreground256: 8);

/// The usage rows of [parser], leaving out [skip] and hidden options.
// ponytail: ArgParser.addSeparator text is not public, so separators are
// dropped; render them if args exposes them.
List<(String, List<_Words>)> _flagRows(ArgParser parser, String? skip) {
  final rows = <(String, List<_Words>)>[];
  for (final option in parser.options.values) {
    if (option.hide || option.name == skip) continue;
    final abbr = option.abbr == null ? '    ' : '-${option.abbr}, ';
    final name = option.isFlag && option.negatable == true
        ? '--[no-]${option.name}'
        : '--${option.name}';
    final value = option.isFlag ? '' : '=<${option.valueHelp ?? 'value'}>';
    final helpLines = (option.help ?? '').split('\n').map(_words).toList();
    final help = helpLines.last;
    final allowed = option.allowed;
    final allowedHelp = option.allowedHelp;
    if (allowed != null && allowedHelp == null) {
      help.add(('[${allowed.join(', ')}]', _dim));
    }
    final defaults = option.defaultsTo;
    final shown = switch (defaults) {
      true when option.isFlag => 'on',
      Iterable<Object?> list when list.isNotEmpty => list.join(', '),
      String text when text.isNotEmpty => text,
      _ => null,
    };
    // One unit each, so a line break never splits them.
    if (shown != null) help.add(('(default: $shown)', _dim));
    if (option.mandatory) help.add(('(required)', _dim));
    final right = helpLines;
    if (allowedHelp != null) {
      final keys = allowed ?? allowedHelp.keys.toList();
      final pad = keys.fold<int>(0, (w, k) => max(w, textWidth(k) + 2));
      for (final key in keys) {
        final lines = (allowedHelp[key] ?? '').split('\n');
        for (var i = 0; i < lines.length; i++) {
          right.add([
            (
              i == 0 ? '[$key]${' ' * (pad - textWidth(key) - 2)}' : ' ' * pad,
              _accent
            ),
            ..._words(lines[i]),
          ]);
        }
      }
    }
    rows.add(('$abbr$name$value', right));
  }
  return rows;
}

String _title(String text) => text.endsWith(':') ? text : '$text:';

/// The command list, grouped by category as `CommandRunner.usage` does:
/// sorted by name, uncategorised first, hidden ones left out unless all
/// are hidden.
List<String> _commandList(
  Map<String, Command<Object?>> commands,
  String title,
  int width,
  _Paint paint,
) {
  var names = commands.keys
      .where((name) => !commands[name]!.aliases.contains(name))
      .toList();
  final visible = names.where((name) => !commands[name]!.hidden).toList();
  if (visible.isNotEmpty) names = visible;
  names.sort();
  final byCategory = SplayTreeMap<String, List<String>>();
  for (final name in names) {
    byCategory.putIfAbsent(commands[name]!.category, () => []).add(name);
  }
  final column = names.fold<int>(0, (w, name) => max(w, textWidth(name)));
  final out = <String>[];
  for (final MapEntry(key: category, value: group) in byCategory.entries) {
    if (out.isNotEmpty) out.add('');
    out.add(paint(_heading, _title(category.isEmpty ? title : category)));
    out.addAll(_table(
      [
        for (final name in group) (name, [_words(commands[name]!.summary)]),
      ],
      width,
      paint,
      column: column,
    ));
  }
  return out;
}

String _help({
  required _Paint paint,
  required int width,
  required String? description,
  required String invocation,
  required Map<String, Command<Object?>> commands,
  required String commandsTitle,
  required List<(String, ArgParser, String?)> flags,
  List<String> examples = const [],
  String? hint,
  String? footer,
}) {
  final sections = <List<String>>[
    if (description != null && description.isNotEmpty)
      _paragraph(description, width, paint),
    [
      paint(_heading, 'Usage:'),
      ..._paragraph(invocation, width, paint, indent: 2),
    ],
    if (commands.isNotEmpty)
      _commandList(commands, commandsTitle, width, paint),
    for (final (title, parser, skip) in flags)
      if (_flagRows(parser, skip) case final rows when rows.isNotEmpty)
        [paint(_heading, _title(title)), ..._table(rows, width, paint)],
    if (examples.isNotEmpty)
      [
        paint(_heading, 'Examples:'),
        for (final example in examples)
          ..._paragraph(example, width, paint, indent: 2),
      ],
    if (hint != null) _paragraph(hint, width, paint),
    if (footer != null && footer.isNotEmpty) _paragraph(footer, width, paint),
  ];
  return sections.map((lines) => lines.join('\n')).join('\n\n');
}
