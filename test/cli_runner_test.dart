import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/grapheme_width.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

Never _throwExit(int code) => throw _Exit(code);

/// A runner writing to [out] and [err]. [color] forces true colour through
/// FORCE_COLOR; [plain] turns plain mode on through ACCESSIBLE.
_App _app(
  CaptureSink out,
  CaptureSink err, {
  bool color = false,
  bool plain = false,
  int width = 80,
  Map<String, String> env = const {},
}) =>
    _App(
      Logger(
        stdout: out,
        stderr: err,
        environment: {
          ...env,
          if (color) 'FORCE_COLOR': '3',
          if (plain) 'ACCESSIBLE': '1',
        },
        exit: _throwExit,
      ),
      width,
    );

class _App extends CliRunner<int> {
  _App(Logger logger, int width)
      : super('tool', 'Builds and ships projects.',
            version: '2.1.0', logger: logger, usageLineLength: width) {
    argParser.addOption('config',
        abbr: 'c',
        help: 'Read settings from this file.',
        defaultsTo: 'tool.yaml');
    addCommand(_Build());
    addCommand(_Deploy());
    addCommand(_Status());
    addCommand(_Probe());
  }

  @override
  String get usageFooter => 'Docs: https://example.com/tool';
}

class _Build extends CliCommand<int> {
  _Build() {
    argParser
      ..addOption('mode',
          abbr: 'm',
          help: 'How to compile.',
          allowed: ['debug', 'release'],
          allowedHelp: {
            'debug': 'Fast builds with asserts.',
            'release': 'Optimised builds.',
          },
          defaultsTo: 'debug')
      ..addOption('target',
          valueHelp: 'os',
          help: 'The platform to build for. A long help text, so that it '
              'wraps onto a second line at the narrow width.',
          allowed: ['linux', 'macos', 'windows'],
          defaultsTo: 'linux')
      ..addMultiOption('define',
          abbr: 'D', help: 'Defines a constant.', defaultsTo: ['a=1', 'b=2'])
      ..addFlag('cache', help: 'Reuse earlier outputs.', defaultsTo: true)
      ..addOption('out', help: 'The output folder.', mandatory: true)
      ..addFlag('secret', hide: true);
  }

  @override
  String get name => 'build';
  @override
  String get description => 'Compile the project.\n\nRuns every step:\n'
      '  1. fetch dependencies\n  2. compile';
  @override
  String get category => 'Project';
  @override
  List<String> get examples => [
        'tool build --mode release',
        'tool build -D name=value --no-cache',
      ];

  @override
  int run() => 0;
}

class _Deploy extends CliCommand<int> {
  @override
  String get name => 'deploy';
  @override
  String get description => 'Upload the latest build to the server.';
  @override
  String get category => 'Project';
  @override
  int run() => 0;
}

class _Status extends CliCommand<int> {
  @override
  String get name => 'status';
  @override
  String get description => 'Show what changed since the last deploy.';
  @override
  int run() => 0;
}

/// Records what the global flags set while it runs, then does [action].
class _Probe extends CliCommand<int> {
  Level? level;
  ColorProfile? profile;
  String? progressOutput;
  FutureOr<int> Function()? action;

  @override
  String get name => 'probe';
  @override
  String get description => 'Test probe.';
  @override
  bool get hidden => true;

  @override
  FutureOr<int> run() {
    level = logger.level;
    profile = Style.defaultProfile;
    logger.progress('Working').complete();
    return action?.call() ?? 0;
  }
}

void main() {
  late CaptureSink out;
  late CaptureSink err;

  setUp(() {
    out = CaptureSink();
    err = CaptureSink();
    final profile = Style.defaultProfile;
    final dark = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.trueColor;
    Style.hasDarkBackground = true;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = dark;
      io.exitCode = 0;
    });
  });

  Future<int> exitCodeOf(CliRunner<int> runner, List<String> args) async {
    try {
      await runner.runAndExit(args);
    } on _Exit catch (e) {
      return e.code;
    }
  }

  group('help', () {
    for (final width in [60, 100]) {
      for (final color in [true, false]) {
        final mode = color ? 'color' : 'plain';
        test('runner and command help at $width columns, $mode', () {
          final app = _app(out, err, color: color, plain: !color, width: width);
          final runnerHelp = app.usage;
          final commandHelp = app.commands['build']!.usage;
          expect(runnerHelp.contains('\x1b['), color);
          expectScreen(
              runnerHelp, 'test/goldens/cli_runner/help_${width}_$mode.txt');
          expectScreen(
              commandHelp, 'test/goldens/cli_runner/build_${width}_$mode.txt');
          // The same layout either way.
          if (color) {
            expect(plainScreen(runnerHelp),
                _app(out, err, plain: true, width: width).usage);
          }
          for (final line in [
            ...plainScreen(runnerHelp).split('\n'),
            ...plainScreen(commandHelp).split('\n'),
          ]) {
            expect(line.length, lessThanOrEqualTo(width), reason: line);
          }
        });
      }
    }

    test('long option cells stay within the help width', () {
      final app = _app(out, err, plain: true, width: 60)
        ..argParser.addOption('this-is-a-fairly-long-option',
            valueHelp: 'a-long-value',
            help: 'This help has many short words that all fit the line.');
      for (final line in app.usage.split('\n')) {
        expect(textWidth(line), lessThanOrEqualTo(60), reason: line);
      }
    });

    test('long examples wrap to the help width', () {
      final app = _app(out, err, plain: true, width: 60)
        ..addCommand(_HelpDetails());
      for (final line in app.commands['details']!.usage.split('\n')) {
        expect(textWidth(line), lessThanOrEqualTo(60), reason: line);
      }
    });

    test('multiline option help aligns every line', () {
      final app = _app(out, err, plain: true)
        ..argParser.addOption('message', help: 'First line.\nSecond line.');
      final lines = app.usage.split('\n');
      final first = lines.singleWhere((line) => line.contains('First line.'));
      final second = lines.singleWhere((line) => line.contains('Second line.'));
      expect(second.indexOf('Second'), first.indexOf('First'));
    });

    test('multiline allowed help aligns continuation descriptions', () {
      final app = _app(out, err, plain: true)
        ..argParser.addOption('choice', allowed: [
          'one'
        ], allowedHelp: {
          'one': 'First line.\nSecond line.',
        });
      final lines = app.usage.split('\n');
      final first = lines.singleWhere((line) => line.contains('First line.'));
      final second = lines.singleWhere((line) => line.contains('Second line.'));
      expect(second.indexOf('Second'), first.indexOf('First'));
    });

    test('allowed help aligns wide labels by terminal columns', () {
      final app = _app(out, err, plain: true)
        ..argParser.addOption('choice', allowed: [
          '界',
          'abc'
        ], allowedHelp: {
          '界': 'First choice.',
          'abc': 'Second choice.',
        });
      final lines = app.usage.split('\n');
      final first = lines.singleWhere((line) => line.contains('First choice.'));
      final second =
          lines.singleWhere((line) => line.contains('Second choice.'));
      expect(textWidth(first.substring(0, first.indexOf('First'))),
          textWidth(second.substring(0, second.indexOf('Second'))));
    });

    test('--help, help <command> and no command print help to stdout',
        () async {
      final app = _app(out, err);
      expect(await exitCodeOf(app, ['--help']), 0);
      expect(out.text, '${app.usage}\n');
      out.clear();
      expect(await exitCodeOf(app, []), 0);
      expect(out.text, '${app.usage}\n');
      out.clear();
      expect(await exitCodeOf(app, ['help', 'build']), 0);
      expect(out.text, '${app.commands['build']!.usage}\n');
      out.clear();
      expect(await exitCodeOf(app, ['build', '--help']), 0);
      expect(out.text, '${app.commands['build']!.usage}\n');
      expect(err.text, isEmpty);
    });

    test('help shows even with --quiet', () async {
      final app = _app(out, err);
      await app.run(['--quiet', '--help']);
      expect(out.text, contains('Usage:'));
    });

    test('NO_COLOR and --no-color give no escapes; --color forces them',
        () async {
      expect(_app(out, err, env: {'NO_COLOR': '1'}).usage,
          isNot(contains('\x1b')));
      await _app(out, err, color: true).run(['--no-color', '--help']);
      expect(out.text, contains('Usage:'));
      expect(out.text, isNot(contains('\x1b')));
      out.clear();
      // Not a terminal and no FORCE_COLOR: no colour without the flag.
      expect(_app(out, err).usage, isNot(contains('\x1b')));
      await _app(out, err).run(['--color', '--help']);
      expect(out.text, contains('\x1b['));
    });
  });

  group('global flags', () {
    test('set the level, colour and plain mode, and are restored', () async {
      final app = _app(out, err);
      final probe = app.commands['probe']! as _Probe;
      final logger = app.logger;

      await app.run(['probe']);
      expect(probe.level, Level.info);
      expect(probe.profile, ColorProfile.trueColor);
      // Not plain: the progress redraws its line.
      expect(out.text, contains('\r'));

      out.clear();
      await app.run(['--verbose', '--no-color', '--plain', 'probe']);
      expect(probe.level, Level.verbose);
      expect(probe.profile, ColorProfile.noColor);
      expect(out.text, startsWith('Working...\n✓ Working'));
      expect(out.text, isNot(contains('\r')));

      await app.run(['-q', 'probe']);
      expect(probe.level, Level.quiet);

      await app.run(['--color', 'probe']);
      expect(probe.profile, ColorProfile.ansi);

      expect(logger.level, Level.info);
      expect(Style.defaultProfile, ColorProfile.trueColor);
      out.clear();
      logger.progress('After').complete();
      expect(out.text, contains('\r'));
    });

    test('are restored when the command throws', () async {
      final app = _app(out, err);
      (app.commands['probe']! as _Probe).action = () => throw StateError('x');
      await expectLater(
          app.run(['-v', '--no-color', 'probe']), throwsStateError);
      expect(app.logger.level, Level.info);
      expect(Style.defaultProfile, ColorProfile.trueColor);
    });

    test('an injectable prompt exit restores the scope', () async {
      final app = _app(out, err);
      (app.commands['probe']! as _Probe).action = () => _throwExit(130);
      await expectLater(
          app.run(['--verbose', '--no-color', '--plain', 'probe']),
          throwsA(isA<_Exit>().having((exit) => exit.code, 'code', 130)));
      expect(app.logger.level, Level.info);
      expect(Style.defaultProfile, ColorProfile.trueColor);
      out.clear();
      app.logger.progress('After').complete();
      expect(out.text, contains('\r'));
    });

    test('--version prints the version; without one there is no flag',
        () async {
      expect(await exitCodeOf(_app(out, err), ['--version']), 0);
      expect(out.text, 'tool version 2.1.0\n');
      final bare = CliRunner<int>('bare', 'No version.',
          logger: Logger(stdout: out, stderr: err, environment: const {}));
      expect(bare.usage, isNot(contains('--version')));
    });

    test('a user option with the same name wins over a global flag', () {
      final runner = CliRunner<int>('app', 'Clashes.',
          version: '1.0.0',
          logger: Logger(stdout: out, stderr: err, environment: const {}))
        ..argParser.addOption('color', help: 'Paint colour.')
        ..argParser.addFlag('quick', abbr: 'q', help: 'Go fast.')
        ..addCommand(_Verbose());
      final help = runner.usage;
      expect(help, isNot(contains('--verbose')));
      expect(help, isNot(contains('--[no-]color')));
      expect(help, contains('--color=<value>   Paint colour.'));
      // -q is taken, so --quiet comes without an abbreviation.
      expect(help, contains('    --quiet'));
      expect(help, contains('-q, --[no-]quick'));
      expect(help, contains('--plain'));
      expect(help, contains('--version'));
    });

    test('recursive command abbreviations block global abbreviations', () {
      final app = _app(out, err);
      final parent = _OptionCommand('parent');
      final child = _OptionCommand('child')
        ..argParser.addFlag('verify', abbr: 'v');
      parent.addSubcommand(child);
      app.addCommand(parent);
      expect(app.usage, isNot(contains('-v, --verbose')));
      expect(app.usage, contains('    --verbose'));
    });

    test('nested runs restore the outer and initial state', () async {
      final app = _app(out, err);
      final probe = app.commands['probe']! as _Probe;
      probe.action = () async {
        probe.action = null;
        await app.run(['--quiet', '--color', 'probe']);
        expect(app.logger.level, Level.verbose);
        expect(Style.defaultProfile, ColorProfile.noColor);
        return 0;
      };
      await app.run(['--verbose', '--no-color', 'probe']);
      expect(app.logger.level, Level.info);
      expect(Style.defaultProfile, ColorProfile.trueColor);
      await app.run(['probe']);
      expect(probe.level, Level.info);
      expect(probe.profile, ColorProfile.trueColor);
    });

    test('a command option named no-color also blocks --color', () {
      final runner = CliRunner<int>('app', 'Clashes.',
          logger: Logger(stdout: out, stderr: err, environment: const {}))
        ..addCommand(_NoColor());
      expect(runner.usage, isNot(contains('--[no-]color')));
    });
  });

  group('errors and exit codes', () {
    test('0 on success, and an int result is the exit code', () async {
      final app = _app(out, err);
      expect(await exitCodeOf(app, ['status']), 0);
      expect(io.exitCode, 0);
      (app.commands['probe']! as _Probe).action = () => 3;
      expect(await exitCodeOf(app, ['probe']), 3);
      expect(io.exitCode, 3);
    });

    test('an unknown command shows suggestions and exits 64', () async {
      final app = _app(out, err, color: true);
      expect(await exitCodeOf(app, ['buidl']), 64);
      expect(out.text, isEmpty);
      final text = plainScreen(err.text);
      expect(
          text,
          startsWith('Error: Could not find a command named "buidl".\n\n'
              'Did you mean this?\n  build\n\nUsage:\n  tool <command>'));
      expect(text, isNot(contains('Builds and ships projects.')));
      expect(err.text, contains('\x1b['));

      err.clear();
      expect(await exitCodeOf(app, ['--no-color', 'stats']), 64);
      expect(err.text, isNot(contains('\x1b')));
      expect(err.text, contains('Did you mean this?\n  status\n'));

      err.clear();
      final two = _app(out, err)
        ..addCommand(_NoColor())
        ..addCommand(_Plain());
      // args keeps one suggestion per edit distance: plain is 1, paint 2.
      expect(await exitCodeOf(two, ['plait']), 64);
      expect(err.text,
          contains('Did you mean one of these?\n  plain\n  paint\n\nUsage:'));
    });

    test('a bad option shows the command usage and exits 64', () async {
      final app = _app(out, err, plain: true);
      expect(await exitCodeOf(app, ['build', '--mode', 'fast']), 64);
      // args 2.5 says "mode", 2.7 says "--mode".
      expect(
          err.text,
          matches(RegExp(r'^Error: "fast" is not an allowed value for option '
              r'"(--)?mode"\.\n\nUsage:\n  tool build \[arguments\]\n')));
      expect(err.text, contains('Examples:'));
      err.clear();
      expect(await exitCodeOf(app, ['--nope']), 64);
      expect(err.text, startsWith('Error: Could not find an option named '));
    });

    test('a UsageException from a plain Command prints its own usage',
        () async {
      final app = _app(out, err)..addCommand(_Plain());
      expect(await exitCodeOf(app, ['plain']), 64);
      expect(err.text, contains('Error: no good\n\nUsage: tool plain'));
    });

    test(
        'an unexpected error is one line and exits 70; --verbose adds the '
        'stack trace', () async {
      final app = _app(out, err);
      (app.commands['probe']! as _Probe).action =
          () => throw StateError('disk\nfull');
      expect(await exitCodeOf(app, ['probe']), 70);
      expect(err.text, 'Error: Bad state: disk full\n');
      expect(io.exitCode, 70);
      err.clear();
      expect(await exitCodeOf(app, ['--verbose', 'probe']), 70);
      final lines = err.text.split('\n');
      expect(lines.first, 'Error: Bad state: disk full');
      expect(lines.length, greaterThan(2));
      expect(err.text, contains('cli_runner_test.dart'));
    });

    test('errors show even with --quiet', () async {
      final app = _app(out, err);
      expect(await exitCodeOf(app, ['-q', 'nope']), 64);
      expect(err.text, startsWith('Error: '));
    });

    test('quiet applies while delayed messages flush', () async {
      final app = _app(out, err);
      app.logger.delayed('later');
      expect(await exitCodeOf(app, ['--quiet', 'status']), 0);
      expect(out.text, isEmpty);
      expect(app.logger.level, Level.info);
    });

    test('runAndExit flushes delayed messages before exiting', () async {
      final app = _app(out, err);
      app.logger.delayed('later');
      expect(await exitCodeOf(app, ['status']), 0);
      expect(out.text, 'later\n');
    });

    test('exit awaits both sinks after delayed output and setting exitCode',
        () async {
      final events = <String>[];
      final logger = Logger(
        stdout:
            _OrderedSink('out', events, onWrite: () => expect(io.exitCode, 3)),
        stderr: _OrderedSink('err', events),
        environment: const {},
        exit: (code) {
          expect(io.exitCode, 3);
          expect(events, ['out:later\n', 'out flushed', 'err flushed']);
          return _throwExit(code);
        },
      );
      final app = CliRunner<int>('app', '', logger: logger)
        ..addCommand(_OptionCommand('status', result: 3));
      io.exitCode = 17;
      logger.delayed('later');
      expect(await exitCodeOf(app, ['--verbose', 'status']), 3);
      expect(logger.level, Level.info);
    });

    test('run keeps CommandRunner semantics: errors are thrown', () async {
      final app = _app(out, err);
      await expectLater(app.run(['nope']), throwsA(isA<UsageException>()));
      expect(err.text, isEmpty);
      final error = await app
          .run(['nope']).then<Object?>((_) => null, onError: (Object e) => e);
      expect((error! as UsageException).usage, startsWith('Usage:\n'));
      expect((error as UsageException).usage, isNot(contains('\x1b')));
    });

    test('a CliCommand outside a CliRunner says so', () {
      final runner = CommandRunner<int>('raw', 'Raw.')..addCommand(_Status());
      expect(() => runner.commands['status']!.usage, throwsStateError);
    });
  });

  test('port check: the args example runs after renaming the base classes',
      () async {
    final logger = Logger(stdout: out, stderr: err, environment: const {});
    final runner = CliRunner<String>('draw', 'Draws shapes', logger: logger)
      ..addCommand(SquareCommand())
      ..addCommand(CircleCommand())
      ..addCommand(TriangleCommand());
    runner.argParser
        .addOption('char', help: 'The character to use for drawing');
    expect(await runner.run(['square', '--size', '2', '--char', '*']),
        '***\n***\n***\n');
    expect(await runner.run(['t', 'e', '--size', '3']), isNotEmpty);
    expect(await runner.run(['c', '--radius', '1']), isNotEmpty);
    expect(runner.usage, contains('square'));
  });
}

class _Verbose extends CliCommand<int> {
  _Verbose() {
    argParser.addFlag('verbose', help: 'Command-level verbose.');
  }
  @override
  String get name => 'run';
  @override
  String get description => 'Runs.';
  @override
  int run() => 0;
}

class _NoColor extends CliCommand<int> {
  _NoColor() {
    argParser.addFlag('no-color', help: 'Monochrome output.');
  }
  @override
  String get name => 'paint';
  @override
  String get description => 'Paints.';
}

class _Plain extends Command<int> {
  @override
  String get name => 'plain';
  @override
  String get description => 'A plain args command.';
  @override
  int run() => usageException('no good');
}

// The args package's example/command_runner/draw.dart, with CommandRunner
// and Command renamed to CliRunner and CliCommand.

class SquareCommand extends CliCommand<String> {
  SquareCommand() {
    argParser.addOption('size', help: 'Size of the square');
  }

  @override
  String get name => 'square';

  @override
  String get description => 'Draws a square';

  @override
  List<String> get aliases => ['s'];

  @override
  FutureOr<String>? run() {
    final size = int.parse(argResults?.option('size') ?? '20');
    final char = globalResults?.option('char')?[0] ?? '#';
    return draw(size, size, char, (x, y) => true);
  }
}

class CircleCommand extends CliCommand<String> {
  CircleCommand() {
    argParser.addOption('radius', help: 'Radius of the circle');
  }

  @override
  String get name => 'circle';

  @override
  String get description => 'Draws a circle';

  @override
  List<String> get aliases => ['c'];

  @override
  FutureOr<String>? run() {
    final size = 2 * int.parse(argResults?.option('radius') ?? '10');
    final char = globalResults?.option('char')?[0] ?? '#';
    return draw(size, size, char, (x, y) => x * x + y * y < 1);
  }
}

class TriangleCommand extends CliCommand<String> {
  TriangleCommand() {
    addSubcommand(EquilateralTriangleCommand());
    addSubcommand(IsoscelesTriangleCommand());
  }

  @override
  String get name => 'triangle';

  @override
  String get description => 'Draws a triangle';

  @override
  List<String> get aliases => ['t'];
}

class EquilateralTriangleCommand extends CliCommand<String> {
  EquilateralTriangleCommand() {
    argParser.addOption('size', help: 'Size of the triangle');
  }

  @override
  String get name => 'equilateral';

  @override
  String get description => 'Draws an equilateral triangle';

  @override
  List<String> get aliases => ['e'];

  @override
  FutureOr<String>? run() {
    final size = int.parse(argResults?.option('size') ?? '20');
    final char = globalResults?.option('char')?[0] ?? '#';
    return drawTriangle(size, size * sqrt(3) ~/ 2, char);
  }
}

class IsoscelesTriangleCommand extends CliCommand<String> {
  IsoscelesTriangleCommand() {
    argParser.addOption('width', help: 'Width of the triangle');
    argParser.addOption('height', help: 'Height of the triangle');
  }

  @override
  String get name => 'isosceles';

  @override
  String get description => 'Draws an isosceles triangle';

  @override
  List<String> get aliases => ['i'];

  @override
  FutureOr<String>? run() {
    final width = int.parse(argResults?.option('width') ?? '50');
    final height = int.parse(argResults?.option('height') ?? '10');
    final char = globalResults?.option('char')?[0] ?? '#';
    return drawTriangle(width, height, char);
  }
}

String draw(
    int width, int height, String char, bool Function(double, double) pixel) {
  final out = StringBuffer();
  for (var y = 0; y <= height; ++y) {
    final ty = 2 * y / height - 1;
    for (var x = 0; x <= width; ++x) {
      final tx = 2 * x / width - 1;
      out.write(pixel(tx, ty) ? char : ' ');
    }
    out.write('\n');
  }
  return out.toString();
}

String drawTriangle(int width, int height, String char) {
  return draw(width, height, char, (x, y) => x.abs() <= (1 + y) / 2);
}

class _OptionCommand extends CliCommand<int> {
  _OptionCommand(this.name, {this.result = 0});
  final int result;
  @override
  final String name;
  @override
  String get description => '';
  @override
  int run() => result;
}

class _HelpDetails extends _OptionCommand {
  _HelpDetails() : super('details');
  @override
  List<String> get examples => [
        'tool details --message one two three four five six seven eight nine '
            'ten eleven twelve thirteen fourteen fifteen',
      ];
}

class _OrderedSink implements io.IOSink {
  _OrderedSink(this.name, this.events, {this.onWrite});
  final void Function()? onWrite;
  final String name;
  final List<String> events;

  @override
  void write(Object? object) {
    onWrite?.call();
    events.add('$name:$object');
  }

  @override
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    events.add('$name flushed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
