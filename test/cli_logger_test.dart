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

void main() {
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
