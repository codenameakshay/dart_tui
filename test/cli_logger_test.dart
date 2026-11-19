import 'dart:async';
import 'dart:convert';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

final class _Exit implements Exception {
  _Exit(this.code);
  final int code;
}

Never _throwExit(int code) => throw _Exit(code);

/// A logger writing to [out] and [err], in plain mode when [plain].
Logger _logger(
  CaptureSink out,
  CaptureSink err, {
  bool plain = false,
  Level level = Level.info,
  Stream<List<int>>? stdin,
  Map<String, String> env = const {},
  ProgressOptions progressOptions = const ProgressOptions(),
}) =>
    Logger(
      level: level,
      stdout: out,
      stderr: err,
      stdin: stdin,
      environment: {...env, if (plain) 'ACCESSIBLE': '1'},
      progressOptions: progressOptions,
      exit: _throwExit,
    );

Stream<List<int>> _lines(String text) => Stream.value(utf8.encode(text));

/// What a terminal shows for [text]: `\r` returns to column 0, `\x1b[K`
/// erases to the end of the line, other characters overwrite.
List<String> _screen(String text) {
  final lines = <String>[];
  var line = <String>[];
  var col = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (text.startsWith('\x1b[K', i)) {
      line = line.sublist(0, col);
      i += 2;
    } else if (c == '\r') {
      col = 0;
    } else if (c == '\n') {
      lines.add(line.join());
      line = [];
      col = 0;
    } else {
      if (col < line.length) {
        line[col] = c;
      } else {
        line.add(c);
      }
      col++;
    }
  }
  if (line.isNotEmpty) lines.add(line.join());
  return lines;
}

TuiTester _drive(Future<Object?> Function() body) {
  final t = TuiTester.run(body);
  addTearDown(t.dispose);
  return t;
}

final class _ManualPeriodicTimer implements Timer {
  _ManualPeriodicTimer(this.callback);
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (!isActive) return;
    tick++;
    callback(this);
  }
}

String _withoutElapsed(String text) => text.replaceAll(
      RegExp(r'\(\d+ms\)|\(\d+\.\ds\)'),
      '(T)',
    );

List<String> _liveScreen(String text) {
  final rows = <List<String>>[[]];
  var row = 0, column = 0;
  final csi = RegExp(r'\x1b\[(\d*)([A-Za-z])');
  for (var i = 0; i < text.length; i++) {
    final match = csi.matchAsPrefix(text, i);
    if (match != null) {
      switch (match[2]) {
        case 'A':
          row = (row - (int.tryParse(match[1]!) ?? 1)).clamp(0, row);
        case 'K':
          rows[row].length = column.clamp(0, rows[row].length);
        case 'J':
          rows[row].length = column.clamp(0, rows[row].length);
          rows.length = row + 1;
      }
      i = match.end - 1;
    } else if (text[i] == '\r') {
      column = 0;
    } else if (text[i] == '\n') {
      row++;
      column = 0;
      if (rows.length <= row) rows.add([]);
    } else {
      while (rows[row].length <= column) {
        rows[row].add(' ');
      }
      rows[row][column++] = text[i];
    }
  }
  final lines = rows.map((row) => row.join()).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

void main() {
  group('Progress byte compatibility', () {
    const options = ProgressOptions(
      animation: Spinner(['A', 'B'], Duration(seconds: 1)),
    );
    test('a completed partial write resumes frames with baseline bytes', () {
      final out = CaptureSink();
      final timers = <_ManualPeriodicTimer>[];
      runZoned(() {
        final logger = _logger(out, CaptureSink(), progressOptions: options);
        final p = logger.progress('Work');
        logger.write('part');
        timers.single.fire();
        logger.write('ial\n');
        timers.single.fire();
        p.cancel();
      }, zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = _ManualPeriodicTimer(callback);
          timers.add(timer);
          return timer;
        },
      ));
      expect(
          _withoutElapsed(out.text),
          '\rA Work... (T)\x1b[K\r\x1b[Kpartial\n'
          '\rB Work... (T)\x1b[K\rA Work... (T)\x1b[K\r\x1b[K');
    });

    for (final ending in ['complete', 'fail', 'cancel', 'takeover']) {
      for (final partial in [false, true]) {
        test('$ending with partial=$partial matches 530c46a', () {
          final timers = <_ManualPeriodicTimer>[];
          final out = CaptureSink(), err = CaptureSink();
          runZoned(() {
            final logger = _logger(out, err, progressOptions: options);
            final p = logger.progress('Work');
            timers.single.fire();
            logger.info('note');
            logger.warn('warn');
            p.update('Next');
            if (partial) {
              logger.write('part');
              timers.single.fire();
              logger.write('ial');
            }
            switch (ending) {
              case 'complete':
                p.complete('Done');
              case 'fail':
                p.fail('Bad');
              case 'cancel':
                p.cancel();
              case 'takeover':
                final next = logger.progress('Other');
                p.complete('Ignored');
                if (partial) logger.write(' end\n');
                next.cancel();
            }
          }, zoneSpecification: ZoneSpecification(
            createPeriodicTimer: (self, parent, zone, duration, callback) {
              final timer = _ManualPeriodicTimer(callback);
              timers.add(timer);
              return timer;
            },
          ));
          const frameA = '\rA Work... (T)\x1b[K';
          const frameB = '\rB Work... (T)\x1b[K';
          const nextFrame = '\rB Next... (T)\x1b[K';
          final prefix = '$frameA$frameB\r\x1b[Knote\n$frameB'
              '\r\x1b[K$frameB$nextFrame'
              '${partial ? '\r\x1b[Kpartial' : ''}';
          final suffix = switch (ending) {
            'complete' => '${partial ? '\n' : ''}\r✓ Done (T)\x1b[K\n',
            'fail' => '${partial ? '\n' : ''}\r✗ Bad (T)\x1b[K\n',
            'cancel' => partial ? '' : '\r\x1b[K',
            _ => partial
                ? ' end\n\rA Other... (T)\x1b[K\r\x1b[K'
                : '\rA Other... (T)\x1b[K\r\x1b[K',
          };
          expect(_withoutElapsed(out.text), '$prefix$suffix');
          expect(err.text, '[WARN] warn\n');
          expect(timers.every((timer) => !timer.isActive), isTrue);
        });
      }
    }
  });

  group('Logger live region', () {
    test('partial writes, stderr and shrinking frames preserve earlier logs',
        () async {
      final out = CaptureSink();
      final timers = <_ManualPeriodicTimer>[];
      final one = Completer<void>(), two = Completer<void>();
      await runZoned(() async {
        final logger = _logger(out, out);
        final run = logger.tasks([
          Task('One', (task) async {
            task.log('detail');
            await one.future;
          }),
          Task('Two', (_) => two.future),
        ], concurrency: 2);
        timers.single.fire();
        logger.write('part');
        expect(out.text, endsWith('\r\x1b[2A\x1b[Jpart'));
        final partial = out.text;
        timers.single.fire();
        expect(out.text, partial);
        logger.write('ial\n');
        logger.warn('warning');
        expect(_liveScreen(out.text).take(2), ['partial', '[WARN] warning']);
        one.complete();
        await Future<void>.delayed(Duration.zero);
        timers.single.fire();
        expect(out.text, endsWith('\x1b[K\x1b[J'));
        expect(_liveScreen(out.text), [
          'partial',
          '[WARN] warning',
          matches(RegExp(r'^✓ One \(.*\)$')),
          matches(RegExp(r'^. Two$')),
        ]);
        two.complete();
        await run;
        logger.info('after');
        expect(_liveScreen(out.text).last, 'after');
        expect(timers.single.isActive, isFalse);
      }, zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = _ManualPeriodicTimer(callback);
          timers.add(timer);
          return timer;
        },
      ));
    });

    test('a final frame taller than the terminal is released before reuse',
        () async {
      final out = CaptureSink();
      final logger = _logger(out, CaptureSink());
      await logger.tasks([
        for (var i = 0; i < 30; i++) Task('Task $i', (_) {}),
      ]);
      final lines = _liveScreen(out.text);
      expect(lines, hasLength(31));
      for (var i = 0; i < 30; i++) {
        expect(lines[i], startsWith('✓ Task $i ('));
      }
      expect(lines.last, startsWith('✓ 30 tasks ('));
      final previous = out.text;
      logger.info('after');
      expect(out.text.substring(previous.length), 'after\n');
      final p = logger.progress('again');
      p.cancel();
      await logger.tasks([Task('Next', (_) {})]);
      expect(_liveScreen(out.text).last, startsWith('✓ 1 task ('));
    });

    for (final complete in [false, true]) {
      test('Progress complete=$complete leaves no rows for the next task list',
          () async {
        final out = CaptureSink();
        final logger = _logger(out, CaptureSink());
        final p = logger.progress('first');
        if (complete) {
          p.complete();
        } else {
          p.cancel();
        }
        final previous = out.text;
        await logger.tasks([Task('Next', (_) {})]);
        expect(out.text.substring(previous.length), isNot(contains('\x1b[1A')));
        final lines = _liveScreen(out.text);
        expect(lines, hasLength(complete ? 3 : 2));
        expect(lines.last, startsWith('✓ 1 task ('));
      });
    }
  });

  group('Logger writes', () {
    test('each method writes to stdout or stderr, as mason_logger does', () {
      final out = CaptureSink(), err = CaptureSink();
      _logger(out, err)
        ..info('i')
        ..success('s')
        ..warn('w')
        ..warn('bare', tag: '')
        ..err('e')
        ..alert('a')
        ..write('raw');
      expect(out.text, 'i\ns\nraw');
      expect(err.text, '[WARN] w\nbare\ne\na\n');
    });

    test('detail writes to stdout at Level.debug and below', () {
      final out = CaptureSink(), err = CaptureSink();
      _logger(out, err).detail('hidden');
      _logger(out, err, level: Level.debug).detail('shown');
      expect(out.text, 'shown\n');
    });

    test('level filtering', () {
      String run(Level level) {
        final out = CaptureSink(), err = CaptureSink();
        _logger(out, err, level: level)
          ..detail('d')
          ..info('i')
          ..success('s')
          ..warn('w', tag: '')
          ..err('e')
          ..alert('a');
        return '${out.text}|${err.text}'.replaceAll('\n', '');
      }

      expect(run(Level.verbose), 'dis|wea');
      expect(run(Level.debug), 'dis|wea');
      expect(run(Level.info), 'is|wea');
      expect(run(Level.warning), '|wea');
      expect(run(Level.error), '|ea');
      expect(run(Level.critical), '|a');
      expect(run(Level.quiet), '|');
    });

    test('styles follow colour detection; plain mode writes no escapes', () {
      final out = CaptureSink(), err = CaptureSink();
      _logger(out, err, env: {'FORCE_COLOR': '3'})
        ..success('ok')
        ..err('bad');
      expect(out.text, contains('\x1b['));
      expect(err.text, contains('\x1b['));

      final plainOut = CaptureSink(), plainErr = CaptureSink();
      _logger(plainOut, plainErr, plain: true, env: {'FORCE_COLOR': '3'})
        ..success('ok')
        ..info('x', style: (m) => '\x1b[31m$m\x1b[0m')
        ..alert('bad')
        ..warn('careful');
      expect(plainOut.text, 'ok\nx\n');
      expect(plainErr.text, 'bad\n[WARN] careful\n');
    });

    test('NO_COLOR and a non-terminal sink give no colour', () {
      final out = CaptureSink(), err = CaptureSink();
      _logger(out, err)
        ..success('ok')
        ..err('e');
      _logger(out, err, env: {'NO_COLOR': '1', 'TERM': 'xterm-256color'})
          .success('ok');
      expect(out.text + err.text, isNot(contains('\x1b')));
    });

    test('a custom style replaces the default', () {
      final out = CaptureSink(), err = CaptureSink();
      _logger(out, err).info('m', style: (m) => '<$m>');
      expect(out.text, '<m>\n');
    });

    test('delayed messages wait for flush', () {
      final out = CaptureSink(), err = CaptureSink();
      final logger = _logger(out, err)
        ..delayed('one')
        ..delayed('two');
      expect(out.text, isEmpty);
      logger.flush();
      expect(out.text, 'one\ntwo\n');
      final seen = <String?>[];
      logger
        ..delayed('three')
        ..flush(seen.add)
        ..flush();
      expect(seen, ['three']);
      expect(out.text, 'one\ntwo\n');
    });
  });

  group('Logger prompts in the TUI', () {
    test('prompt shows the default and returns it on Enter', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.prompt('Name?', defaultValue: 'app'));
      await t.waitFor((s) => s.contains('Name? (app)'));
      await t.press('enter');
      final result = await t.done();
      expect(result.value, 'app');
      expect(result.screen, 'Name? (app) app');
    });

    test('prompt returns the trimmed answer', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.prompt('Name?'));
      await t.type(' Ada ');
      await t.press('enter');
      expect((await t.done()).value, 'Ada');
    });

    test('hidden input is not shown', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.prompt('Token?', hidden: true));
      await t.type('hunter2');
      expect(t.screen, 'Token? •••••••█');
      await t.press('enter');
      final result = await t.done();
      expect(result.value, 'hunter2');
      expect(result.screen, 'Token? ******');
    });

    test('promptAny splits on the separator', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.promptAny('Tags?', separator: ';'));
      await t.type('a; b;;c ');
      await t.press('enter');
      expect((await t.done()).value, ['a', 'b', 'c']);
    });

    for (final (key, defaultValue, want) in [
      ('enter', true, true),
      ('enter', false, false),
      ('n', true, false),
      ('y', false, true),
    ]) {
      test('confirm: $key with default $defaultValue returns $want', () async {
        final logger = _logger(CaptureSink(), CaptureSink());
        final t =
            _drive(() => logger.confirm('Go?', defaultValue: defaultValue));
        await t.waitFor((s) => s.contains(defaultValue ? '[Y/n]' : '[y/N]'));
        await t.press(key);
        final result = await t.done();
        expect(result.value, want);
        expect(result.screen, 'Go? ${want ? 'Yes' : 'No'}');
      });
    }

    test('chooseOne starts on the default and maps display back', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.chooseOne<int>(
            'Size?',
            choices: [1, 2, 3],
            defaultValue: 2,
            display: (n) => 'size $n',
          ));
      await t.waitFor((s) => s.contains('> size 2'));
      await t.press('down');
      await t.press('enter');
      final result = await t.done();
      expect(result.value, 3);
      expect(result.screen, 'Size? size 3');
    });

    test('chooseOne wraps from the last choice to the first', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.chooseOne('Pick',
          choices: ['a', 'b', 'c'], defaultValue: 'c'));
      await t.waitFor((s) => s.contains('> c'));
      await t.press('down');
      await t.press('enter');
      expect((await t.done()).value, 'a');
    });

    test('chooseOne with no choices throws', () {
      final logger = _logger(CaptureSink(), CaptureSink());
      expect(() => logger.chooseOne('x', choices: const <String>[]),
          throwsArgumentError);
    });

    test('duplicate display labels preserve the selected choice index',
        () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.chooseOne<int>(
            'Pick',
            choices: [1, 2],
            display: (_) => 'same',
          ));
      await t.press('down');
      await t.press('enter');
      expect((await t.done()).value, 2);
    });

    test('duplicate display labels preserve multi-select indices', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.chooseAny<int>(
            'Pick',
            choices: [1, 2],
            display: (_) => 'same',
          ));
      await t.press('down');
      await t.press('space');
      await t.press('enter');
      expect((await t.done()).value, [2]);
    });

    test('chooseAny starts with the defaults checked', () async {
      final logger = _logger(CaptureSink(), CaptureSink());
      final t = _drive(() => logger.chooseAny(
            'Features?',
            choices: ['a', 'b', 'c'],
            defaultValues: ['c', 'missing'],
          ));
      await t.waitFor((s) => s.contains('[x] c'));
      expect(t.screen, contains('[ ] a'));
      await t.press('space');
      await t.press('enter');
      final result = await t.done();
      expect(result.value, ['a', 'c']);
      expect(result.screen, 'Features? [a, c]');
    });

    for (final key in ['esc', 'ctrl+c']) {
      test('$key cancels and exits with 130', () async {
        final logger = _logger(CaptureSink(), CaptureSink());
        final t = _drive(() => logger.confirm('Go?'));
        await t.press(key);
        await expectLater(
            t.done(), throwsA(isA<_Exit>().having((e) => e.code, 'code', 130)));
      });
    }
  });

  group('Logger prompts in plain mode', () {
    Future<(T, String)> ask<T>(
      String input,
      Future<T> Function(Logger logger) body,
    ) async {
      final out = CaptureSink();
      final value = await body(
          _logger(out, CaptureSink(), plain: true, stdin: _lines(input)));
      expect(out.text, isNot(contains('\x1b')));
      return (value, out.text);
    }

    test('prompt answers and defaults', () async {
      expect(
          await ask('Ada\n', (l) => l.prompt('Name?')), ('Ada', 'Name? Ada\n'));
      expect(await ask('\n', (l) => l.prompt('Name?', defaultValue: 'app')),
          ('app', 'Name? (app) \n'));
    });

    test('hidden input is not echoed', () async {
      final (value, text) =
          await ask('hunter2\n', (l) => l.prompt('Token?', hidden: true));
      expect(value, 'hunter2');
      expect(text, 'Token? \n');
    });

    test('confirm, chooseOne, chooseAny and promptAny', () async {
      expect(await ask('\n', (l) => l.confirm('Go?', defaultValue: true)),
          (true, 'Go? (Y/n) \n'));
      final (one, _) = await ask('\n',
          (l) => l.chooseOne('Pick', choices: ['a', 'b'], defaultValue: 'b'));
      expect(one, 'b');
      final (any, text) = await ask(
          '\n',
          (l) => l.chooseAny('Pick',
              choices: ['a', 'b', 'c'], defaultValues: ['a', 'c']));
      expect(any, ['a', 'c']);
      expect(text, contains('[1,3]: '));
      final (two, _) =
          await ask('2\n', (l) => l.chooseAny('Pick', choices: ['a', 'b']));
      expect(two, ['b']);
      final (tags, _) = await ask('x, y\n', (l) => l.promptAny('Tags?'));
      expect(tags, ['x', 'y']);
    });

    test('plain selection maps duplicate labels by chosen index', () async {
      final logger = _logger(CaptureSink(), CaptureSink(),
          plain: true, stdin: _lines('2\n'));
      expect(
        await logger.chooseOne<int>('Pick',
            choices: [1, 2], display: (_) => 'same'),
        2,
      );
    });

    test('plain multi-select preserves duplicate display-label indices',
        () async {
      final logger = _logger(CaptureSink(), CaptureSink(),
          plain: true, stdin: _lines('2\n'));
      expect(
        await logger.chooseAny<int>('Pick',
            choices: [1, 2], display: (_) => 'same'),
        [2],
      );
    });

    test('the end of input returns the defaults instead of exiting', () async {
      expect(
          (await ask('', (l) => l.prompt('Name?', defaultValue: 7))).$1, '7');
      expect((await ask('', (l) => l.confirm('Go?'))).$1, isFalse);
      final (one, _) = await ask('',
          (l) => l.chooseOne('Pick', choices: ['a', 'b'], defaultValue: 'b'));
      expect(one, 'b');
      final (any, _) = await ask(
          '',
          (l) =>
              l.chooseAny('Pick', choices: ['a', 'b'], defaultValues: ['b']));
      expect(any, ['b']);
      expect((await ask('', (l) => l.promptAny('Tags?'))).$1, isEmpty);
    });
  });

  group('Progress', () {
    const fast = ProgressOptions(
      animation: Spinner(['A', 'B', 'C'], Duration(milliseconds: 5)),
    );

    test('frames advance on one line', () async {
      final out = CaptureSink();
      final p = _logger(out, CaptureSink(), progressOptions: fast)
          .progress('Working');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      p.complete();
      for (final frame in ['A', 'B', 'C']) {
        expect(out.text, contains('\r$frame Working... ('));
      }
      expect(out.text, isNot(contains('\x1b[?25l')));
      final lines = _screen(out.text);
      expect(lines, hasLength(1));
      expect(lines.single, matches(RegExp(r'^✓ Working \(\d+ms\)$')));
    });

    test('Logger writes during a progress clear the line and redraw it',
        () async {
      final out = CaptureSink(), err = CaptureSink();
      final logger = _logger(out, err, progressOptions: fast);
      final p = logger.progress('Working');
      logger
        ..info('hello')
        ..warn('careful');
      p.update('Still working');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      p.fail('Broke');
      logger.info('after');
      expect(_screen(out.text), [
        'hello',
        matches(RegExp(r'^✗ Broke \(\d+ms\)$')),
        'after',
      ]);
      expect(out.text, contains('Still working...'));
      expect(err.text, '[WARN] careful\n');
    });

    test('partial writes are not overwritten by progress timer frames',
        () async {
      final out = CaptureSink();
      final logger = _logger(out, CaptureSink(), progressOptions: fast);
      final p = logger.progress('Working');
      addTearDown(p.cancel);
      logger.write('partial');
      final before = out.text.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(out.text.substring(before), isEmpty);
      p.cancel();
      expect(_screen(out.text).single, 'partial');
    });

    test('partial write followed by complete ends before the result line', () {
      final out = CaptureSink();
      final logger = _logger(out, CaptureSink(), progressOptions: fast);
      final p = logger.progress('Working');
      addTearDown(p.cancel);
      logger.write('partial');
      p.complete();
      expect(_screen(out.text), [
        'partial',
        matches(RegExp(r'^✓ Working \(\d+ms\)$')),
      ]);
    });

    test('empty writes do not suppress progress frames', () async {
      final out = CaptureSink();
      final logger = _logger(out, CaptureSink(), progressOptions: fast);
      final p = logger.progress('Working');
      addTearDown(p.cancel);
      logger.write('');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      p.cancel();
      expect(out.text, contains('Working...'));
    });

    test('cancel removes the line; ending twice writes once', () async {
      final out = CaptureSink();
      final p =
          _logger(out, CaptureSink(), progressOptions: fast).progress('Gone');
      p.cancel();
      p.complete();
      expect(_screen(out.text).join(), isEmpty);
    });

    test('custom trailing text is truncated to fit one terminal row', () {
      final out = CaptureSink();
      final logger = _logger(
        out,
        CaptureSink(),
        progressOptions: ProgressOptions(trailing: '!' * 200),
      );
      final p = logger.progress('Working');
      addTearDown(p.cancel);
      expect(_screen(out.text).single.length, lessThanOrEqualTo(79));
    });

    test('multiline messages stay on one progress row', () async {
      final out = CaptureSink();
      final logger = _logger(out, CaptureSink(), progressOptions: fast);
      final p = logger.progress('First\nSecond');
      addTearDown(p.cancel);
      p.complete('Done\nnow');
      expect(_screen(out.text), [
        matches(RegExp(r'^✓ Done now \(\d+ms\)$')),
      ]);
    });

    test('the elapsed time switches from ms to seconds', () async {
      final out = CaptureSink();
      final p =
          _logger(out, CaptureSink(), progressOptions: fast).progress('Slow');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      p.complete();
      expect(_screen(out.text).single, matches(RegExp(r'^✓ Slow \(0\.1s\)$')));
    });

    test('plain mode writes one start line and one end line', () async {
      final out = CaptureSink();
      final logger =
          _logger(out, CaptureSink(), plain: true, progressOptions: fast);
      final p = logger.progress('Building');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      logger.info('note');
      p.complete('Built');
      logger.progress('Other').cancel();
      expect(
          out.text,
          matches(RegExp(
              r'^Building\.\.\.\nnote\n✓ Built \(\d+ms\)\nOther\.\.\.\n$')));
    });

    test('below Level.info it writes nothing', () {
      final out = CaptureSink();
      _logger(out, CaptureSink(), level: Level.warning)
          .progress('quiet')
          .complete();
      expect(out.text, isEmpty);
    });

    test('a long message is cut to keep one line', () async {
      final out = CaptureSink();
      final p = _logger(out, CaptureSink(), progressOptions: fast)
          .progress('x' * 200);
      p.cancel();
      expect(out.text, contains('${'x' * 65}...'));
      expect(out.text, isNot(contains('x' * 66)));
    });

    test('does not listen to stdin; a later prompt still gets input', () async {
      final input = StreamController<List<int>>();
      final logger = _logger(CaptureSink(), CaptureSink(),
          stdin: input.stream, progressOptions: fast);
      final p = logger.progress('Working');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      p.complete();
      expect(input.hasListener, isFalse);
      final answer = logger.confirm('Go?');
      input.add(utf8.encode('y'));
      expect(await answer, isTrue);
      await input.close();
    });
  });

  group('prompt helpers', () {
    test('promptMultiSelect toggles and returns checked labels', () async {
      final t = _drive(() => promptMultiSelect(['a', 'b', 'c'], initial: {2}));
      expect(t.screen, contains('[x] c'));
      expect(t.screen, contains('Space toggle'));
      await t.press('space');
      await t.press('down');
      await t.press('x');
      await t.press('enter');
      expect((await t.done()).value, ['a', 'b', 'c']);
    });

    test('promptMultiSelect cancel returns null; no choices returns []',
        () async {
      final t = _drive(() => promptMultiSelect(['a']));
      await t.press('esc');
      expect((await t.done()).value, isNull);
      expect(await promptMultiSelect([]), isEmpty);
    });

    test('promptMultiSelect in plain mode', () async {
      final out = CaptureSink();
      final picks = await promptMultiSelect(['a', 'b', 'c'],
          title: 'Pick',
          options: [
            withPlainMode(),
            withEnvironment(const {}),
            withInput(_lines('3,1\n')),
            withOutput(out),
          ]);
      expect(picks, ['a', 'c']);
      expect(out.text,
          'Pick\n1. a\n2. b\n3. c\nEnter numbers separated by commas: 3,1\n');
    });

    test('promptSelect starts on initial; plain empty input picks it',
        () async {
      final t = _drive(() => promptSelect(['a', 'b'], initial: 1));
      expect(t.screen, contains('> b'));
      await t.press('enter');
      expect((await t.done()).value, 'b');

      final out = CaptureSink();
      final plain = await promptSelect(['a', 'b'],
          initial: 1,
          options: [
            withPlainMode(),
            withEnvironment(const {}),
            withInput(_lines('\n')),
            withOutput(out),
          ]);
      expect(plain, 'b');
      expect(out.text, endsWith('Enter a number [2]: \n'));
    });

    test('promptSelect keeps its label outcome for TuiTester', () async {
      final t = _drive(() => promptSelect(['a', 'a', 'b'], initial: 1));
      await t.press('enter');
      final result = await t.done();
      expect(result.value, 'a');
      expect(result.outcome, 'a');
    });

    test('promptInput hidden and defaultValue', () async {
      final t = _drive(() => promptInput('pw', hidden: true));
      await t.type('ab');
      expect(t.screen, 'pw ••█');
      await t.press('enter');
      expect((await t.done()).value, 'ab');

      final d = _drive(() => promptInput('name', defaultValue: 'x'));
      await d.press('enter');
      expect((await d.done()).value, 'x');
    });

    test('promptConfirm defaultValue true', () async {
      final t = _drive(() => promptConfirm('ok?', defaultValue: true));
      expect(t.screen, startsWith('ok? [Y/n]'));
      await t.press('enter');
      expect((await t.done()).value, isTrue);
    });
  });
}
