import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/posix_terminal.dart' show posixInputReady;
import 'package:dart_tui/src/program.dart'
    show
        ProgramTestHook,
        SyncPromptInput,
        programTestHookKey,
        promptExitKey,
        syncPromptInputKey;
import 'package:dart_tui/src/windows_terminal.dart' show windowsInputReady;
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Bytes for a sync prompt, read in key chunks. After each chunk the source
/// pauses, as a person does between keys, so a trailing ESC is a lone Escape.
final class _Keys implements SyncPromptInput {
  _Keys(List<String> chunks) {
    for (final chunk in chunks) {
      _bytes.addAll(utf8.encode(chunk));
      _bytes.add(null);
    }
  }

  final _bytes = Queue<int?>();

  int get unread => _bytes.whereType<int>().length;

  @override
  int readByte() {
    while (_bytes.isNotEmpty) {
      final byte = _bytes.removeFirst();
      if (byte != null) return byte;
    }
    return -1;
  }

  @override
  bool waitForByte(Duration timeout) {
    if (_bytes.isEmpty) return true; // end of input reads at once
    if (_bytes.first != null) return true;
    _bytes.removeFirst();
    return false;
  }
}

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

Never _throwExit(int code) => throw _Exit(code);

final class _WindowsReleaseCycle extends Model {
  _WindowsReleaseCycle(this.program, this.modes);
  final Program program;
  final List<(bool, bool)> modes;

  void recordModes() => modes.add((stdin.lineMode, stdin.echoMode));

  @override
  Cmd? init() => () async {
        await program.releaseTerminal();
        recordModes();
        await program.releaseTerminal();
        recordModes();
        await program.restoreTerminal();
        recordModes();
        await program.releaseTerminal();
        recordModes();
        return quit();
      };

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}

/// Runs [body] with [keys] as its input; returns its value and its output.
({T value, String out}) _sync<T>(
  T Function(List<ProgramOption> options) body,
  List<String> keys, {
  Map<String, String> env = const {},
  bool plain = false,
}) {
  final sink = CaptureSink();
  final options = [
    withOutput(sink),
    withEnvironment(env),
    if (plain) withPlainMode(),
  ];
  final value = runZoned(() => body(options), zoneValues: {
    syncPromptInputKey: _Keys(keys),
    promptExitKey: _throwExit,
  });
  return (value: value, out: sink.text);
}

/// The output of the async twin for the same [keys], one chunk at a time,
/// without the capability queries a [Program] sends after its first frame.
Future<({Object? value, String out})> _async(
  Future<Object?> Function(List<ProgramOption> options) body,
  List<String> keys,
) async {
  final sink = CaptureSink();
  final input = StreamController<List<int>>();
  final done = body([
    withInput(input.stream),
    withOutput(sink),
    withEnvironment(const {}),
  ]);
  var finished = false;
  unawaited(done.whenComplete(() => finished = true));
  Future<void> settle() async {
    var last = -1;
    for (var i = 0; i < 200 && !finished; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final length = sink.text.length;
      if (length == last && length > 0) return;
      last = length;
    }
  }

  await settle();
  for (final chunk in keys) {
    if (finished) break;
    input.add(utf8.encode(chunk));
    await settle();
  }
  final value = await done.timeout(const Duration(seconds: 5));
  await input.close();
  final out = sink.text
      .replaceAll('\x1b[?2026\$p', '')
      .replaceAll('\x1b[?2027\$p', '')
      .replaceAll('\x1b]11;?\x07', '');
  return (value: value, out: out);
}

const _esc = '\x1b';
const _down = '\x1b[B';
const _ctrlC = '\x03';

void main() {
  test(
    'Windows raw-mode exit preserves the original echo setting',
    () async {
      final originalLineMode = stdin.lineMode;
      final originalEchoMode = stdin.echoMode;
      final modes = <(bool, bool)>[];
      try {
        stdin.lineMode = true;
        stdin.echoMode = false;
        final program = Program(options: [
          withInput(null),
          withOutput(CaptureSink()),
          withoutSignalHandler(),
        ]);
        await program.run(_WindowsReleaseCycle(program, modes));
        expect(modes, [
          (true, false),
          (true, false),
          (false, false),
          (true, false),
        ]);
        // Shutdown while already released must not replace the original
        // console mode with cooked/echoing input.
        expect(stdin.echoMode, isFalse);
        expect(stdin.lineMode, isTrue);
      } finally {
        stdin.echoMode = originalEchoMode;
        stdin.lineMode = originalLineMode;
      }
    },
    skip: !Platform.isWindows
        ? 'requires Windows'
        : !stdin.hasTerminal
            ? 'requires a real Windows console on stdin'
            : false,
  );

  group('frames equal the async prompt', () {
    final cases = <(
      String,
      Object? Function(List<ProgramOption>),
      Future<Object?> Function(List<ProgramOption>),
      List<String>,
    )>[
      (
        'confirm',
        (o) => promptConfirmSync('Go?', options: o),
        (o) => promptConfirm('Go?', options: o),
        ['y'],
      ),
      (
        'select',
        (o) => promptSelectSync(['a', 'b', 'c'], options: o),
        (o) => promptSelect(['a', 'b', 'c'], options: o),
        [_down, _down, 'k', '\r'],
      ),
      (
        'multi-select',
        (o) => promptMultiSelectSync(['a', 'b', 'c'], options: o),
        (o) => promptMultiSelect(['a', 'b', 'c'], options: o),
        [' ', _down, 'x', 'a', '\r'],
      ),
      (
        'input',
        (o) => promptInputSync('Name', options: o),
        (o) => promptInput('Name', options: o),
        ['A', 'd', 'x', '\x7f', 'a', '\r'],
      ),
      (
        'hidden input',
        (o) => promptInputSync('Token', hidden: true, options: o),
        (o) => promptInput('Token', hidden: true, options: o),
        ['s', '3', '\r'],
      ),
      (
        'esc',
        (o) => promptSelectSync(['a', 'b'], options: o),
        (o) => promptSelect(['a', 'b'], options: o),
        [_down, _esc],
      ),
    ];
    for (final (name, sync, asyncPrompt, keys) in cases) {
      test(name, () async {
        final expected = await _async(asyncPrompt, keys);
        final actual = _sync(sync, keys);
        expect(actual.value, expected.value);
        expect(actual.out, expected.out);
      });
    }
  });

  group('promptConfirmSync', () {
    for (final (keys, defaultValue, want) in [
      (['y'], false, true),
      (['Y'], false, true),
      (['n'], true, false),
      (['\r'], false, false),
      (['\r'], true, true),
      (['\n'], true, true), // LF is ctrl+j on some terminals
      (['q', 'y'], false, true), // other keys are ignored
    ]) {
      test('$keys with default $defaultValue returns $want', () {
        final r = _sync(
          (o) =>
              promptConfirmSync('Go?', defaultValue: defaultValue, options: o),
          keys,
        );
        expect(r.value, want);
      });
    }

    test('a lone Esc cancels at once, without another byte', () {
      final input = _Keys([_esc, 'y']);
      final value = runZoned(
        () => promptConfirmSync('Go?', options: [withOutput(CaptureSink())]),
        zoneValues: {syncPromptInputKey: input},
      );
      expect(value, isNull);
      expect(input.unread, 1, reason: 'the y after Esc stays unread');
    });

    test('Esc as the last byte of input cancels', () {
      expect(_sync((o) => promptConfirmSync('Go?', options: o), ['\x1b']).value,
          isNull);
    });

    test('end of input returns null', () {
      expect(
          _sync((o) => promptConfirmSync('Go?', options: o), []).value, isNull);
    });

    test('Alt+key (ESC then a key in one chunk) is not Escape', () {
      expect(
          _sync((o) => promptConfirmSync('Go?', options: o), ['\x1by', 'n'])
              .value,
          isFalse);
    });
  });

  group('Ctrl+C', () {
    final prompts = <String, Object? Function(List<ProgramOption>)>{
      'confirm': (o) => promptConfirmSync('Go?', options: o),
      'select': (o) => promptSelectSync(['a', 'b'], options: o),
      'multi-select': (o) => promptMultiSelectSync(['a', 'b'], options: o),
      'input': (o) => promptInputSync('Name', options: o),
    };
    for (final MapEntry(key: name, value: prompt) in prompts.entries) {
      test('$name restores the terminal, then exits with 130', () {
        final sink = CaptureSink();
        Object? error;
        try {
          runZoned(() => prompt([withOutput(sink)]), zoneValues: {
            syncPromptInputKey: _Keys(['a', _ctrlC, 'y']),
            promptExitKey: _throwExit,
          });
        } on _Exit catch (e) {
          error = e.code;
        }
        expect(error, 130);
        final out = sink.text;
        // The cursor is shown again after it was hidden, on a fresh line.
        expect(out.lastIndexOf('\x1b[?25h'),
            greaterThan(out.lastIndexOf('\x1b[?25l')));
        expect(out, endsWith('\n'));
      });
    }
  });

  test('a write that fails while closing still restores the colour defaults',
      () {
    final before = Style.defaultProfile;
    Style.defaultProfile = ColorProfile.ansi;
    addTearDown(() => Style.defaultProfile = before);
    final sink = _FailingSink('\x1b[?25h');
    expect(
      () => runZoned(
        () => promptConfirmSync('Go?', options: [withOutput(sink)]),
        zoneValues: {
          syncPromptInputKey: _Keys(['y'])
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(Style.defaultProfile, ColorProfile.ansi);
  });

  group('promptSelectSync', () {
    test('arrows and Enter pick; an arrow is not a lone Esc', () {
      final r = _sync(
          (o) => promptSelectSync(['a', 'b', 'c'], options: o), [_down, '\r']);
      expect(r.value, 'b');
    });

    test('initial is where the cursor starts', () {
      expect(
          _sync(
              (o) => promptSelectSync(['a', 'b', 'c'], initial: 2, options: o),
              ['\r']).value,
          'c');
    });

    test('empty choices return null without reading', () {
      final input = _Keys(['x']);
      final value = runZoned(() => promptSelectSync([]),
          zoneValues: {syncPromptInputKey: input});
      expect(value, isNull);
      expect(input.unread, 1);
    });
  });

  group('promptMultiSelectSync', () {
    test('space and x toggle, a toggles all; picks keep list order', () {
      final r = _sync(
        (o) => promptMultiSelectSync(['a', 'b', 'c'], initial: {2}, options: o),
        [' ', _down, _down, 'x', '\r'],
      );
      expect(r.value, ['a']);
      final all = _sync(
        (o) => promptMultiSelectSync(['a', 'b', 'c'], options: o),
        ['a', '\r'],
      );
      expect(all.value, ['a', 'b', 'c']);
    });

    test('Enter keeps initial; empty choices return []', () {
      expect(
          _sync(
              (o) => promptMultiSelectSync(['a', 'b', 'c'],
                  initial: {2, 0}, options: o),
              ['\r']).value,
          ['a', 'c']);
      expect(promptMultiSelectSync([]), isEmpty);
    });
  });

  group('promptInputSync', () {
    test('typing, backspace and a multi-byte character', () {
      final r = _sync((o) => promptInputSync('Name', options: o),
          ['A', 'd', 'x', '\x7f', 'é', '😀', '\r']);
      expect(r.value, 'Adé😀');
    });

    test('empty input returns the default', () {
      expect(
          _sync((o) => promptInputSync('Name', defaultValue: 'app', options: o),
              ['\r']).value,
          'app');
    });

    test('hidden input is never echoed', () {
      final r = _sync((o) => promptInputSync('Token', hidden: true, options: o),
          ['h', 'u', 'n', 't', 'e', 'r', '2', '\r']);
      expect(r.value, 'hunter2');
      expect(r.out, isNot(contains('hunter2')));
      expect(r.out, contains('Token •••••••█'));
    });

    test('Esc returns null', () {
      expect(
          _sync((o) => promptInputSync('Name', options: o), ['a', _esc]).value,
          isNull);
    });
  });

  group('plain mode', () {
    test('answers from piped lines, like the async prompts', () async {
      final sync = _sync(
        (o) => [
          promptSelectSync(['a', 'b'], title: 'Pick', options: o),
          promptMultiSelectSync(['a', 'b', 'c'], initial: {0}, options: o),
          promptConfirmSync('Go?', options: o),
          promptInputSync('Name', options: o),
          promptInputSync('Token', hidden: true, options: o),
        ],
        ['9\n2\n1,3\nyes\nAda\nsecret\n'],
        plain: true,
      );
      expect(sync.value, [
        'b',
        ['a', 'c'],
        true,
        'Ada',
        'secret',
      ]);
      expect(sync.out, isNot(contains('\x1b')));
      expect(sync.out, isNot(contains('secret')));
      expect(
        sync.out,
        'Pick\n1. a\n2. b\nEnter a number: 9\nEnter a number from 1 to 2.\n'
        'Enter a number: 2\n'
        'Choose any\n1. a\n2. b\n3. c\n'
        'Enter numbers separated by commas [1]: 1,3\n'
        'Go? (y/N) yes\n'
        'Name Ada\n'
        'Token \n',
      );
    });

    test('the transcript matches the async prompt', () async {
      final sink = CaptureSink();
      final asyncValue = await promptSelect(['a', 'b'],
          title: 'Pick',
          initial: 1,
          options: [
            withPlainMode(),
            withEnvironment(const {}),
            withOutput(sink),
            withInput(Stream.value(utf8.encode('x\n\n'))),
          ]);
      final sync = _sync(
        (o) =>
            promptSelectSync(['a', 'b'], title: 'Pick', initial: 1, options: o),
        ['x\n\n'],
        plain: true,
      );
      expect(sync.value, asyncValue);
      expect(sync.out, sink.text);
    });

    test('end of input returns null; a last line without newline counts', () {
      final r = _sync(
        (o) => [
          promptInputSync('A', options: o),
          promptInputSync('B', options: o),
          promptConfirmSync('C', defaultValue: true, options: o),
          promptSelectSync(['x'], options: o),
          promptMultiSelectSync(['x'], options: o),
        ],
        ['last'],
        plain: true,
      );
      expect(r.value, ['last', null, null, null, null]);
    });

    test('ACCESSIBLE=1 turns plain mode on', () {
      final r = _sync((o) => promptConfirmSync('Go?', options: o), ['y\n'],
          env: const {'ACCESSIBLE': '1'});
      expect(r.value, isTrue);
      expect(r.out, 'Go? (y/N) y\n');
    });
  });

  group('refuses what it cannot do', () {
    test('withInput(stream) throws an ArgumentError', () {
      expect(
        () => promptConfirmSync('Go?', options: [
          withInput(const Stream.empty()),
          withOutput(CaptureSink()),
        ]),
        throwsA(isA<ArgumentError>().having(
            (e) => '${e.message}', 'message', contains('promptConfirmSync'))),
      );
      expect(
        () => promptInputSync('Go?', options: [
          withPlainMode(),
          withInput(const Stream.empty()),
          withOutput(CaptureSink()),
        ]),
        throwsArgumentError,
      );
    });

    test('withInput(null) has no input: it returns null', () {
      expect(
          promptConfirmSync('Go?',
              options: [withInput(null), withOutput(CaptureSink())]),
          isNull);
      expect(
          promptInputSync('Go?', options: [
            withInput(null),
            withPlainMode(),
            withOutput(CaptureSink()),
          ]),
          isNull);
    });

    test('under TuiTester it throws a StateError', () {
      expect(
        () => runZoned(() => promptConfirmSync('Go?'),
            zoneValues: {programTestHookKey: _Hook()}),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('TuiTester'))),
      );
    });
  });

  group('Logger', () {
    Logger logger({Map<String, String> env = const {}, CaptureSink? out}) =>
        Logger(
          stdout: out ?? CaptureSink(),
          stderr: CaptureSink(),
          environment: env,
          exit: _throwExit,
        );

    T keys<T>(List<String> keys, T Function() body) =>
        runZoned(body, zoneValues: {syncPromptInputKey: _Keys(keys)});

    test('the sync twins answer like the async methods', () {
      final out = CaptureSink();
      final l = logger(out: out);
      expect(keys(['\r'], () => l.promptSync('Name?', defaultValue: 'app')),
          'app');
      expect(keys([' ', 'a', ' ', '\r'], () => l.promptSync('Name?')), 'a');
      expect(keys(['p', 'w', '\r'], () => l.promptSync('Pw?', hidden: true)),
          'pw');
      expect(
          keys(['a', ';', 'b', '\r'],
              () => l.promptAnySync('Tags?', separator: ';')),
          ['a', 'b']);
      expect(
          keys(['\r'], () => l.confirmSync('Go?', defaultValue: true)), isTrue);
      expect(
          keys(
              [_down, '\r'],
              () =>
                  l.chooseOneSync('Pick', choices: [1, 2, 3], defaultValue: 2)),
          3);
      expect(
          keys(
              [' ', '\r'],
              () => l.chooseAnySync('Any',
                  choices: ['x', 'y'], defaultValues: ['y'])),
          ['x', 'y']);
      // An answered prompt collapses to one line, as in the async Logger.
      expect(out.text, contains('Go?'));
      expect(out.text, contains('Yes'));
      expect(out.text, isNot(contains('pw')));
    });

    test('Esc and Ctrl+C exit with 130', () {
      for (final key in [_esc, _ctrlC]) {
        expect(
          () => keys([key], () => logger().confirmSync('Go?')),
          throwsA(isA<_Exit>().having((e) => e.code, 'code', 130)),
        );
      }
    });

    test('in plain mode, the end of input returns the defaults', () {
      final l = logger(env: const {'ACCESSIBLE': '1'});
      expect(keys([], () => l.promptSync('N?', defaultValue: 7)), '7');
      expect(keys([], () => l.confirmSync('Go?', defaultValue: true)), isTrue);
      expect(
          keys(
              [],
              () =>
                  l.chooseOneSync('P', choices: ['a', 'b'], defaultValue: 'b')),
          'b');
      expect(
          keys(
              [],
              () => l.chooseAnySync('A',
                  choices: ['a', 'b'], defaultValues: ['a'])),
          ['a']);
      expect(keys([], () => l.promptAnySync('T?')), isEmpty);
      expect(
          keys(['2\n'], () => l.chooseOneSync('P', choices: ['a', 'b'])), 'b');
    });

    test('a Logger with a stdin stream refuses the sync methods', () {
      final l = Logger(
        stdout: CaptureSink(),
        stdin: const Stream.empty(),
        environment: const {},
      );
      expect(
          () => l.confirmSync('Go?'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('Logger.confirmSync'))));
      expect(
          () => l.chooseOneSync('P', choices: const []), throwsArgumentError);
    });
  });

  group('input readiness', () {
    // On Windows CI this calls the console functions on a stdin that is not
    // a console; elsewhere it calls poll(2) on the test's stdin.
    test('windowsInputReady and posixInputReady return without blocking', () {
      final clock = Stopwatch()..start();
      windowsInputReady(const Duration(milliseconds: 20));
      posixInputReady(const Duration(milliseconds: 20));
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('shared stdin (subprocess)', () {
    Future<String> probe(String scenario, String input) async {
      final process = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'tool/pty_program_probe.dart', scenario],
      );
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.add(utf8.encode(input));
      await process.stdin.close();
      expect(await process.exitCode.timeout(const Duration(seconds: 30)), 0,
          reason: await errors);
      return output;
    }

    test('refuses to run while an async prompt reads stdin', () async {
      final text = await probe('sync-busy', 'Ada\n');
      expect(
          text,
          contains('SYNC_BUSY=Bad state: promptConfirmSync cannot run '
              'while a Program or an async prompt reads stdin'));
      expect(text, contains('ASYNC_ANSWER=Ada'));
    });

    test('an async prompt draining input after EOF still blocks a sync one',
        () async {
      final text = await probe('sync-busy-eof', 'Ada\nGrace\n');
      expect(text, contains('SYNC_BUSY=Bad state: promptConfirmSync'));
      expect(text, contains('ANSWERS=Ada|Grace'));
    });

    test('a character split between async and sync reads decodes whole',
        () async {
      final process = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'tool/pty_program_probe.dart', 'sync-utf8-split'],
      );
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final output = StringBuffer();
      final firstDone = Completer<void>();
      final stdoutDone = process.stdout.transform(utf8.decoder).forEach((t) {
        output.write(t);
        if ('$output'.contains('FIRST_DONE') && !firstDone.isCompleted) {
          firstDone.complete();
        }
      });
      final errors = process.stderr.transform(utf8.decoder).join();
      // '€' is E2 82 AC: the first write ends after E2 82.
      process.stdin.add([...utf8.encode('Ada\n'), 0xe2, 0x82]);
      await process.stdin.flush();
      await firstDone.future.timeout(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      process.stdin.add([0xac, ...utf8.encode('!\n')]);
      await process.stdin.close();
      expect(await process.exitCode.timeout(const Duration(seconds: 30)), 0,
          reason: await errors);
      await stdoutDone;
      expect('$output', contains('ANSWERS=Ada|€!'));
    });

    test('async and sync plain prompts share piped stdin in order', () async {
      final text = await probe('sync-plain-chain', 'Ada\nGrace\nHopper\n');
      expect(text, contains('ANSWERS=Ada|Grace|Hopper|null'));
      expect(text, isNot(contains('\x1b')));
    });

    test('failed sync cleanup restores styles and unread stdin', () async {
      final text = await probe('sync-cleanup-failure', 'Ada\nyGrace\n');
      expect(text, contains('CLEANUP=Ada|Grace'));
    });
  }, skip: Platform.isWindows ? 'the probe needs a Unix host' : false);
}

final class _Hook implements ProgramTestHook {
  @override
  List<ProgramOption> get options => const [];
  @override
  Model attach(Program program, Model model) => model;
  @override
  bool handleMessage(Msg msg) => false;
  @override
  Model unwrap(Model model) => model;
  @override
  void detach(Program program) {}
}

/// Throws once [trigger] is written, like an output that closes mid-prompt.
final class _FailingSink implements IOSink {
  _FailingSink(this.trigger);
  final String trigger;
  final _text = StringBuffer();

  @override
  void write(Object? object) {
    if ('$object'.contains(trigger)) throw StateError('output closed');
    _text.write(object);
  }

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
