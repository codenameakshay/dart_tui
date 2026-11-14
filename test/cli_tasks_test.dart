import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/cli.dart' show TaskNode, TaskStatus, renderTasks;
import 'package:dart_tui/testing.dart';
import 'package:dart_tui/src/ansi_state.dart' show stripAnsiSequences;
import 'package:test/test.dart';

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

Never _throwExit(int code) => throw _Exit(code);

const _fast = ProgressOptions(
  animation: Spinner(['A', 'B'], Duration(milliseconds: 5)),
);

/// A logger writing to [out] and [err]. Without [plain] it draws the live
/// region.
Logger _logger(
  CaptureSink out,
  CaptureSink err, {
  bool plain = false,
  Level level = Level.info,
  Stream<List<int>>? stdin,
}) =>
    Logger(
      level: level,
      stdout: out,
      stderr: err,
      stdin: stdin,
      environment: {if (plain) 'ACCESSIBLE': '1'},
      progressOptions: _fast,
      exit: _throwExit,
    );

/// What a terminal shows for [text]: `\r`, `\n`, erase to line end (`K`),
/// erase to screen end (`J`), cursor up (`A`); other escapes are ignored.
List<String> _screen(String text) {
  final rows = <List<String>>[<String>[]];
  var row = 0, col = 0;
  final csi = RegExp(r'\x1b\[(\d*)([A-Za-z])');
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    final m = c == '\x1b' ? csi.matchAsPrefix(text, i) : null;
    if (m != null) {
      final n = int.tryParse(m[1]!) ?? 1;
      switch (m[2]) {
        case 'K':
          rows[row] = rows[row].sublist(0, math.min(col, rows[row].length));
        case 'J':
          rows[row] = rows[row].sublist(0, math.min(col, rows[row].length));
          rows.length = row + 1;
        case 'A':
          row = math.max(row - n, 0);
      }
      i = m.end - 1;
    } else if (c == '\r') {
      col = 0;
    } else if (c == '\n') {
      row++;
      col = 0;
      while (rows.length <= row) {
        rows.add(<String>[]);
      }
    } else {
      final line = rows[row];
      while (line.length < col) {
        line.add(' ');
      }
      if (col < line.length) {
        line[col] = c;
      } else {
        line.add(c);
      }
      col++;
    }
  }
  final lines = [for (final r in rows) r.join()];
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

final _times = RegExp(r'\(\d+ms\)|\(\d+\.\ds\)');
String _noTimes(String text) => text.replaceAll(_times, '(T)');
List<String> _noTimeLines(List<String> lines) => lines.map(_noTimes).toList();

Future<void> _wait([int ms = 15]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

const _ms = Duration(milliseconds: 42);
const _s = Duration(milliseconds: 1200);

void _golden(List<String> lines, String name) =>
    expectScreen(lines.join('\n'), 'test/goldens/cli_tasks/$name.txt');

TaskNode _ok(String title, [Duration d = _ms, List<TaskNode>? children]) =>
    TaskNode(title, status: TaskStatus.success, elapsed: d, children: children);

TaskNode _run(String title, {List<String>? output, List<TaskNode>? children}) =>
    TaskNode(title,
        status: TaskStatus.running, output: output, children: children);

void main() {
  group('renderTasks', () {
    test('running task shows its last output line', () {
      _golden(
          renderTasks([
            _ok('Install', _s),
            _run('Build', output: ['compiling a', 'compiling b']),
            TaskNode('Deploy'),
          ], width: 60, height: 24),
          'running');
    });

    test('a running parent shows indented children', () {
      _golden(
          renderTasks([
            _run('Check', children: [
              _ok('Analyze'),
              _run('Test', output: ['+3: ok']),
              TaskNode('Format'),
            ]),
            TaskNode('Build'),
          ], width: 60, height: 24),
          'nested');
    });

    test('a succeeded parent collapses to one line', () {
      final lines = renderTasks([
        _ok('Check', _s, [_ok('Analyze'), _ok('Test')]),
      ], width: 60, height: 24);
      expect(lines, hasLength(1));
      _golden(lines, 'collapsed');
    });

    TaskNode failed() => TaskNode('Test',
        status: TaskStatus.failed,
        elapsed: _s,
        output: [for (var i = 1; i <= 8; i++) 'line $i'],
        error: Exception('2 tests failed'));

    test('a failed task shows the last 5 output lines while live', () {
      final lines = renderTasks([failed()], width: 60, height: 24);
      expect(lines, contains(contains('… 3 earlier lines')));
      expect(lines.any((l) => l.contains('line 3')), isFalse);
      _golden(lines, 'failed_live');
    });

    test('the final frame shows all output and the error', () {
      final lines = renderTasks([failed()], width: 60);
      expect(lines.any((l) => l.contains('earlier')), isFalse);
      expect(lines.any((l) => l.contains('line 1')), isTrue);
      _golden(lines, 'failed_final');
    });

    test('a failure inside a collapsed-looking parent stays expanded', () {
      final lines = renderTasks([
        TaskNode('Check',
            status: TaskStatus.failed,
            elapsed: _s,
            error: const TasksFailed([]),
            children: [
              _ok('Analyze'),
              TaskNode('Test',
                  status: TaskStatus.failed,
                  elapsed: _ms,
                  error: Exception('boom')),
            ]),
      ], width: 60);
      expect(lines, hasLength(4));
      _golden(lines, 'failed_nested');
    });

    test('skipped tasks, with and without a reason', () {
      _golden(
          renderTasks([
            TaskNode('Publish',
                status: TaskStatus.skipped, skipReason: 'dry run'),
            TaskNode('Notify', status: TaskStatus.skipped),
          ], width: 60),
          'skipped');
    });

    test('folds finished tasks into "… n done" when taller than the screen',
        () {
      final nodes = [
        for (var i = 1; i <= 10; i++) _ok('Step $i'),
        _run('Last', output: ['working']),
        TaskNode('After'),
      ];
      final lines = renderTasks(nodes, width: 60, height: 6);
      expect(lines.length, lessThanOrEqualTo(5));
      expect(lines.first, matches(RegExp(r'^… \d+ done$')));
      expect(lines.any((l) => l.contains('Last')), isTrue);
      _golden(lines, 'folded');
      // Plenty of room: nothing folds.
      expect(renderTasks(nodes, width: 60, height: 40), hasLength(13));
    });

    test('no row is wider than width - 1', () {
      final nodes = [
        _ok('A very long finished task title that cannot fit', _s),
        _run('Another long running task title', output: [
          'an output line that is far too long for the terminal',
        ]),
        TaskNode('Pending task with a long name'),
      ];
      final lines = renderTasks(nodes, width: 20, height: 24);
      for (final line in lines) {
        expect(getWidth(line), lessThanOrEqualTo(19), reason: line);
      }
      _golden(lines, 'narrow');
    });

    test('keeps declaration order whatever finishes first', () {
      final lines = renderTasks([
        _ok('first', _s),
        _ok('second', _ms),
        _ok('third', _ms),
      ], width: 40);
      expect([for (final l in lines) l.split(' ')[1]],
          ['first', 'second', 'third']);
    });
  });

  group('plain mode', () {
    Future<void> flow(Logger logger) => logger.tasks([
          Task('Fetch', (t) {
            t.log('one');
            t.log('two');
          }),
          Task('Build', (t) async {
            await t.tasks([
              Task('Compile', (t) => t.log('cc a.c')),
              Task('Link', (t) => t.skip('nothing to do')),
            ]);
          }),
          Task('Off', (t) => fail('never'), enabled: () => false),
        ]);

    test('one line per finished task, prefixed logs, no escapes', () async {
      final out = CaptureSink(), err = CaptureSink();
      await flow(_logger(out, err, plain: true));
      expect(out.text, isNot(contains('\x1b')));
      expect(err.text, isEmpty);
      final lines = _noTimes(out.text).trimRight().split('\n');
      expect(lines, contains('Fetch | one'));
      expect(lines, contains('Build > Compile | cc a.c'));
      expect(lines, contains('✓ Build > Compile (T)'));
      expect(lines, contains('- Build > Link skipped: nothing to do'));
      expect(lines, contains('- Off skipped'));
      _golden(lines, 'plain');
    });
  });

  group('behaviour', () {
    late CaptureSink out, err;
    setUp(() {
      out = CaptureSink();
      err = CaptureSink();
    });

    for (final concurrency in [1, 2, 3]) {
      test('honours concurrency $concurrency', () async {
        var running = 0, seen = 0;
        await _logger(out, err).tasks([
          for (var i = 0; i < 6; i++)
            Task('t$i', (t) async {
              seen = math.max(seen, ++running);
              await _wait();
              running--;
            }),
        ], concurrency: concurrency);
        expect(seen, concurrency);
      });
    }

    test('honours the concurrency of nested steps', () async {
      var running = 0, seen = 0;
      await _logger(out, err).tasks([
        Task(
            'Parent',
            (t) => t.tasks([
                  for (var i = 0; i < 5; i++)
                    Task('c$i', (t) async {
                      seen = math.max(seen, ++running);
                      await _wait();
                      running--;
                    }),
                ], concurrency: 2)),
      ]);
      expect(seen, 2);
    });

    test('tasks that finish in reverse order still render in order', () async {
      await _logger(out, err).tasks([
        Task('a', (t) => _wait(45)),
        Task('b', (t) => _wait(30)),
        Task('c', (t) => _wait(15)),
      ], concurrency: 3);
      expect(_noTimeLines(_screen(out.text)),
          ['✓ a (T)', '✓ b (T)', '✓ c (T)', '✓ 3 tasks (T)']);
    });

    test(
        'exitOnError skips pending tasks, awaits running ones, then throws '
        'after the final frame', () async {
      var slowDone = false;
      final badStarted = Completer<void>();
      final ran = <String>[];
      String? atThrow;
      Object? thrown;
      try {
        await _logger(out, err).tasks([
          Task('Bad', (t) async {
            badStarted.complete();
            throw StateError('nope');
          }),
          Task('Slow', (t) async {
            // Ends only after Bad has failed, so its worker sees the stop.
            await badStarted.future;
            await _wait(10);
            slowDone = true;
          }),
          Task('Later', (t) => ran.add('Later')),
          Task('Last', (t) => ran.add('Last')),
        ], concurrency: 2);
      } on TasksFailed catch (e) {
        thrown = e;
        atThrow = out.text;
      }
      expect(thrown, isA<TasksFailed>());
      expect(slowDone, isTrue);
      expect(ran, isEmpty);
      expect(atThrow, contains('✗ 1 of 4 failed'));
      final failures = (thrown! as TasksFailed).failures;
      expect(failures.map((f) => f.title), ['Bad']);
      expect(failures.single.error, isA<StateError>());
      final screen = _noTimeLines(_screen(out.text));
      expect(screen, contains('✗ Bad (T)'));
      expect(screen.where((l) => l.contains('skipped')), hasLength(2));
      expect(screen.last, '✗ 1 of 4 failed (T)');
    });

    test('failures of nested steps are listed as Parent > Child', () async {
      final ran = <String>[];
      final thrown = await _logger(out, err).tasks([
        Task(
            'Parent',
            (t) => t.tasks([
                  Task('Child', (t) => throw StateError('deep')),
                  Task('Sibling', (t) => ran.add('Sibling')),
                ])),
        Task('Other', (t) => ran.add('Other')),
      ]).then<Object?>((_) => null, onError: (Object e) => e);
      expect(thrown, isA<TasksFailed>());
      final failures = (thrown! as TasksFailed).failures;
      expect(failures.map((f) => f.title), ['Parent > Child']);
      expect(ran, isEmpty);
      expect(out.text, contains('✗ 1 of 4 failed'));
    });

    test('exitOnError: false runs everything and does not throw', () async {
      final ran = <String>[];
      await _logger(out, err).tasks([
        Task('Bad', (t) => throw Exception('x')),
        Task('Good', (t) => ran.add('Good')),
        Task('Bad2', (t) => throw Exception('y')),
      ], exitOnError: false);
      expect(ran, ['Good']);
      expect(_noTimeLines(_screen(out.text)).last, '✗ 2 of 3 failed (T)');
    });

    test('enabled: () => false skips without running', () async {
      var ran = false;
      await _logger(out, err, plain: true).tasks([
        Task('Off', (t) => ran = true, enabled: () => false),
      ]);
      expect(ran, isFalse);
      expect(_noTimes(out.text), '- Off skipped\n✓ 1 task, 1 skipped (T)\n');
    });

    test('task.skip(reason) marks the task skipped', () async {
      var after = false;
      await _logger(out, err, plain: true).tasks([
        Task('Pub', (t) {
          t.skip('why');
        }),
        Task('Nope', (t) {
          t.skip();
        }),
        Task('Sub', (t) {
          after = true;
        }),
      ]);
      expect(after, isTrue);
      expect(out.text, contains('- Pub skipped: why\n'));
      expect(out.text, contains('- Nope skipped\n'));
    });

    test('logger.info during a run lands above the list', () async {
      await _logger(out, err).tasks([
        Task('Work', (t) async {
          await _wait();
        }),
        Task('More', (t) async {
          await _wait();
        }),
      ], concurrency: 2);
      // Run again with a log in the middle.
      out.clear();
      final logger = _logger(out, err);
      await logger.tasks([
        Task('Work', (t) async {
          await _wait(20);
          logger.info('hello');
          await _wait(20);
        }),
        Task('Other', (t) => _wait(40)),
      ], concurrency: 2);
      expect(_noTimeLines(_screen(out.text)),
          ['hello', '✓ Work (T)', '✓ Other (T)', '✓ 2 tasks (T)']);
    });

    test('plain: one line per task, prefixed logs, nested path', () async {
      await _logger(out, err, plain: true).tasks([
        Task('Outer', (t) async {
          t.log('start');
          await t.tasks([Task('Inner', (t) => t.log('deep'))]);
        }),
      ]);
      expect(out.text, isNot(contains('\x1b')));
      expect(
          _noTimes(out.text),
          'Outer | start\nOuter > Inner | deep\n'
          '✓ Outer > Inner (T)\n✓ Outer (T)\n✓ 2 tasks (T)\n');
    });

    test('Level.quiet: stdout is empty, stderr has failures and the summary',
        () async {
      final thrown = await _logger(out, err, level: Level.quiet).tasks([
        Task('Fine', (t) => t.log('hidden')),
        Task('Bad', (t) {
          t.log('first');
          t.log('second');
          throw Exception('bad');
        }),
      ], exitOnError: false).then<Object?>((_) => null,
          onError: (Object e) => e);
      expect(thrown, isNull);
      expect(out.text, isEmpty);
      expect(
          _noTimes(err.text),
          [
            'Bad | first',
            'Bad | second',
            '✗ Bad: Exception: bad',
            '✗ 1 of 2 failed (T)',
          ].map((l) => '$l\n').join());
    });

    test('Level.verbose on the live path prints logged lines above the list',
        () async {
      await _logger(out, err, level: Level.verbose).tasks([
        Task('Job', (t) async {
          t.log('chatter');
          await _wait(20);
        }),
      ]);
      expect(_noTimeLines(_screen(out.text)),
          ['Job | chatter', '✓ Job (T)', '✓ 1 task (T)']);
    });

    test('a Progress inside a task writes plain lines above the list',
        () async {
      final logger = _logger(out, err);
      await logger.tasks([
        Task('Host', (t) async {
          final p = logger.progress('Sub');
          await _wait(20);
          p.complete('Sub done');
        }),
      ]);
      expect(_noTimeLines(_screen(out.text)),
          ['Sub...', '✓ Sub done (T)', '✓ Host (T)', '✓ 1 task (T)']);
    });

    test('a second live list throws StateError; concurrency 0 throws',
        () async {
      final logger = _logger(out, err);
      Object? second, nested;
      await logger.tasks([
        Task('Outer', (t) async {
          second = await logger.tasks([Task('x', (t) {})]).then<Object?>(
              (_) => null,
              onError: (Object e) => e);
          nested = await t.tasks([Task('y', (t) {})],
              concurrency:
                  0).then<Object?>((_) => null, onError: (Object e) => e);
        }),
      ], exitOnError: false);
      expect(second, isA<StateError>());
      expect(nested, isA<ArgumentError>());
      await expectLater(logger.tasks([Task('z', (t) {})], concurrency: 0),
          throwsArgumentError);
    });

    test('never listens to stdin; a later prompt still gets input', () async {
      final input = StreamController<List<int>>();
      final logger = _logger(out, err, stdin: input.stream);
      await logger.tasks([Task('Work', (t) => _wait(20))]);
      expect(input.hasListener, isFalse);
      final answer = logger.confirm('Go?');
      input.add(utf8.encode('y'));
      expect(await answer, isTrue);
      await input.close();
    });
  });

  group('task regressions', () {
    test('duplicate parent titles do not share nested failures', () async {
      final out = CaptureSink(), err = CaptureSink();
      final failed = Completer<void>();
      final otherStarted = Completer<void>();
      var unrelatedFailed = false;
      final error = StateError('bad');
      final result = await _logger(out, err).tasks([
        Task('Parent', (t) async {
          try {
            await t.tasks([
              Task('Bad', (t) async {
                await otherStarted.future;
                throw error;
              })
            ]);
          } finally {
            failed.complete();
          }
        }),
        Task('Parent', (t) async {
          otherStarted.complete();
          await failed.future;
          try {
            await t.tasks([]);
          } on TasksFailed {
            unrelatedFailed = true;
          }
        }),
      ], concurrency: 2).then<Object?>((_) => null, onError: (Object e) => e);
      expect(unrelatedFailed, isFalse);
      final failures = (result! as TasksFailed).failures;
      expect(failures.map((f) => f.title), ['Parent > Bad']);
      expect(failures.single.error, same(error));
      final screen = _noTimeLines(_screen(out.text));
      expect(screen.where((line) => line == '✗ Parent (T)'), hasLength(1));
      expect(screen.where((line) => line == '✓ Parent (T)'), hasLength(1));
    });

    test('an unrelated TasksFailed thrown by a parent is retained', () async {
      final out = CaptureSink(), err = CaptureSink();
      const ownError = TasksFailed([]);
      final result = await _logger(out, err).tasks([
        Task('Parent', (t) async {
          await t.tasks([Task('Good', (t) {})]);
          throw ownError;
        }),
      ]).then<Object?>((_) => null, onError: (Object e) => e);
      expect(result, isA<TasksFailed>());
      final failures = (result! as TasksFailed).failures;
      expect(failures.map((f) => f.title), ['Parent']);
      expect(failures.single.error, same(ownError));
      expect(_screen(out.text), contains('  0 tasks failed: '));
    });

    for (final plain in [false, true]) {
      test('unprintable errors keep their identity and release (plain=$plain)',
          () async {
        final out = CaptureSink(), err = CaptureSink();
        final logger = _logger(out, err, plain: plain);
        final error = _Unprintable();
        final result = await logger.tasks([
          Task('Bad', (t) => throw error),
        ]).then<Object?>((_) => null, onError: (Object e) => e);
        expect(result, isA<TasksFailed>());
        expect((result! as TasksFailed).failures.single.error, same(error));
        expect(result.toString(), contains('unprintable error'));
        final end = out.text;
        await _wait(20);
        expect(out.text, end);
        await logger.tasks([Task('Next', (t) {})]);
        expect(out.text, contains('✓ Next'));
      });
    }

    test('render sanitizes controls without mutating the nodes', () {
      final node = _run('a\tb', output: ['old\rnew\x1b[2J\t界']);
      final rows = renderTasks([node], width: 12, height: 5);
      expect(rows.any((r) => RegExp(r'[\x00-\x1f\x7f]').hasMatch(r)), isFalse);
      for (final row in rows) {
        expect(getWidth(row), lessThanOrEqualTo(11));
      }
      expect(node.title, 'a\tb');
      expect(node.output.single, 'old\rnew\x1b[2J\t界');
    });

    test('render cleans error, skip and spinner text before painting', () {
      final nodes = [
        TaskNode('Failed',
            status: TaskStatus.failed, error: 'old\rerror\x1b[2J\t界'),
        TaskNode('Skip',
            status: TaskStatus.skipped, skipReason: 'old\rwhy\x1b[2J'),
        _run('Run'),
      ];
      final rows = renderTasks(nodes,
          width: 30,
          spinner: const Spinner(['\x1b[2J\tA\rB'], Duration(seconds: 1)),
          paint: (_, text) => '\x1b[31m$text\x1b[0m');
      expect(rows.join(), contains('\x1b[31m'));
      expect(rows.join(), isNot(contains('\x1b[2J')));
      for (final row in rows) {
        final plain = stripAnsiSequences(row);
        expect(RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(plain), isFalse);
        expect(getWidth(row), lessThanOrEqualTo(29));
      }
      expect(stripAnsiSequences(rows[1]), '  error    界');
      expect(stripAnsiSequences(rows[2]), '↓ Skip skipped: why');
      expect(stripAnsiSequences(rows[3]), 'B Run');
    });

    test('enabled errors fail and stop pending tasks at every depth', () async {
      final out = CaptureSink(), err = CaptureSink();
      final otherStarted = Completer<void>(), failed = Completer<void>();
      final events = <String>[];
      final error = StateError('enabled');
      final result = await _logger(out, err, plain: true).tasks([
        Task('First', (t) async {
          await otherStarted.future;
          try {
            await t.tasks([
              Task('Disabled', (t) => events.add('body'),
                  enabled: () => throw error),
              Task('Nested later', (t) => events.add('nested later')),
            ]);
          } finally {
            failed.complete();
          }
        }),
        Task('Running', (t) async {
          otherStarted.complete();
          await failed.future;
          await t
              .tasks([Task('Other child', (t) => events.add('other child'))]);
          events.add('running finished');
        }),
        Task('Later', (t) => events.add('later')),
      ], concurrency: 2).then<Object?>((_) => null, onError: (Object e) => e);
      expect(events, ['running finished']);
      final failures = (result! as TasksFailed).failures;
      expect(failures.map((f) => f.title), ['First > Disabled']);
      expect(failures.single.error, same(error));
      expect(out.text, contains('- First > Nested later skipped'));
      expect(out.text, contains('- Running > Other child skipped'));
      expect(out.text, contains('- Later skipped'));
    });

    test('empty and repeated lists leave no timer or stale state', () async {
      final out = CaptureSink(), err = CaptureSink();
      final logger = _logger(out, err);
      await logger.tasks([]);
      expect(out.text, isEmpty);
      await logger.tasks([Task('First', (t) {})]);
      final first = out.text;
      await logger.tasks([]);
      await _wait(20);
      expect(out.text, first);
      out.clear();
      await logger.tasks([Task('Second', (t) => t.skip())]);
      expect(_noTimeLines(_screen(out.text)),
          ['↓ Second skipped', '✓ 1 task, 1 skipped (T)']);
    });

    test('plain task titles, skip reasons and errors cannot emit escapes',
        () async {
      final out = CaptureSink(), err = CaptureSink();
      await _logger(out, err, plain: true).tasks([
        Task('old\rNew\x1b[2J\tTitle', (t) {
          t.log('\x1b[31mred\x1b[0m\ttext');
          t.skip('old\rreason\x1b[2J');
        }),
        Task('Bad', (t) => throw 'old\rproblem\x1b[2J\ttext'),
      ], exitOnError: false);
      expect(out.text, isNot(contains('\x1b')));
      expect(out.text, isNot(contains('\r')));
      expect(out.text, isNot(contains('\t')));
      expect(out.text, contains('New    Title | red    text'));
      expect(out.text, contains('skipped: reason'));
      expect(out.text, contains('Bad: problem    text'));
    });

    test('a one-row terminal reserves its sole row for the cursor', () {
      expect(renderTasks([TaskNode('a')], width: 10, height: 1), isEmpty);
    });
  });

  group('CliRunner', () {
    test('a failing task list exits 70 with one Error line', () async {
      final out = CaptureSink(), err = CaptureSink();
      final runner = CliRunner<int>('tool', 'Tool.',
          logger: _logger(out, err, plain: true))
        ..addCommand(_Ship());
      Object? exit;
      try {
        await runner.runAndExit(['ship']);
      } on _Exit catch (e) {
        exit = e.code;
      }
      expect(exit, 70);
      expect(err.text.trimRight().split('\n'), hasLength(1));
      expect(err.text, startsWith('Error: '));
      expect(err.text, contains('Compile failed'));
      expect(out.text, contains('✗ 1 of 1 failed'));
    });
  });
}

class _Ship extends CliCommand<int> {
  @override
  String get name => 'ship';
  @override
  String get description => 'Ships.';

  @override
  Future<int> run() async {
    await logger.tasks([
      Task('Compile', (t) => throw StateError('broken')),
    ]);
    return 0;
  }
}

final class _Unprintable {
  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => throw StateError('cannot hash');
  @override
  String toString() => throw StateError('cannot format');
}
