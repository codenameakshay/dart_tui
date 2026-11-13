import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/color_detect.dart' show isPlainOutput;
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 10));

/// Captures what a helper writes.
final class _Out implements StreamConsumer<List<int>> {
  final _bytes = <int>[];
  late final sink = IOSink(this);

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach(_bytes.addAll);
  @override
  Future<void> close() async {}

  Future<String> text() async {
    await sink.flush();
    return utf8.decode(_bytes);
  }
}

/// Plain mode forced, fed [input] as one chunk, writing to [out].
List<ProgramOption> _plain(String input, _Out out) => [
      withPlainMode(),
      withEnvironment(const {}),
      withInput(Stream.value(utf8.encode(input))),
      withOutput(out.sink),
    ];

Future<String> _noEscapes(_Out out) async {
  final text = await out.text();
  expect(text, isNot(contains('\x1b')));
  return text;
}

void main() {
  group('promptSelect', () {
    test('lists numbered choices and returns the picked one', () async {
      final out = _Out();
      final r = await promptSelect(['a', 'b', 'c'],
          title: 'Pick', options: _plain('2\n', out));
      expect(r, 'b');
      expect(
          await _noEscapes(out), 'Pick\n1. a\n2. b\n3. c\nEnter a number: 2\n');
    }, timeout: _timeout);

    test('asks again until the number is valid', () async {
      final out = _Out();
      final r = await promptSelect(['a', 'b'],
          title: 'Pick', options: _plain('0\nb\n\n2\n', out));
      expect(r, 'b');
      const again = 'Enter a number from 1 to 2.\n';
      expect(
        await _noEscapes(out),
        'Pick\n1. a\n2. b\n'
        'Enter a number: 0\n${again}Enter a number: b\n$again'
        'Enter a number: \n${again}Enter a number: 2\n',
      );
    }, timeout: _timeout);

    test('end of input cancels instead of asking again', () async {
      final out = _Out();
      expect(await promptSelect(['a'], title: 'T', options: _plain('9\n', out)),
          isNull);
      expect(
          await _noEscapes(out),
          'T\n1. a\nEnter a number: 9\nEnter a number from 1 to 1.\n'
          'Enter a number: \n');
    }, timeout: _timeout);

    test('withInput(null) cancels at once', () async {
      final out = _Out();
      final r = await promptSelect([
        'a'
      ], options: [
        withPlainMode(),
        withInput(null),
        withOutput(out.sink),
      ]);
      expect(r, isNull);
    }, timeout: _timeout);
  });

  group('promptConfirm', () {
    test('empty input takes the default, yes', () async {
      final out = _Out();
      expect(await promptConfirm('Ship?', options: _plain('\n', out)), isTrue);
      expect(await _noEscapes(out), 'Ship? (Y/n) \n');
    }, timeout: _timeout);

    test('n and no are false, in any case', () async {
      for (final answer in ['n', 'NO', ' No ']) {
        final out = _Out();
        expect(await promptConfirm('Ship?', options: _plain('$answer\n', out)),
            isFalse);
      }
    }, timeout: _timeout);

    test('asks again on other text', () async {
      final out = _Out();
      expect(await promptConfirm('Ship?', options: _plain('maybe\ny\n', out)),
          isTrue);
      expect(await _noEscapes(out),
          'Ship? (Y/n) maybe\nEnter y or n.\nShip? (Y/n) y\n');
    }, timeout: _timeout);

    test('end of input cancels', () async {
      final out = _Out();
      expect(await promptConfirm('Ship?', options: _plain('', out)), isNull);
    }, timeout: _timeout);
  });

  group('promptInput', () {
    test('writes the label and returns the line', () async {
      final out = _Out();
      expect(await promptInput('Name', options: _plain('Ada\n', out)), 'Ada');
      expect(await _noEscapes(out), 'Name Ada\n');
    }, timeout: _timeout);

    test('empty input is empty, CRLF and escape codes are dropped', () async {
      expect(await promptInput('N: ', options: _plain('\n', _Out())), '');
      final out = _Out();
      expect(
          await promptInput('N: ', options: _plain('\x1b[Ahi\r\n', out)), 'hi');
      expect(await _noEscapes(out), 'N: hi\n');
    }, timeout: _timeout);

    test('a last line without a newline still counts; then EOF', () async {
      expect(await promptInput('N:', options: _plain('Ada', _Out())), 'Ada');
      expect(await promptInput('N:', options: _plain('', _Out())), isNull);
    }, timeout: _timeout);
  });

  group('filter', () {
    const flavours = ['Vanilla', 'Chocolate', 'Strawberry'];

    test('takes a number or text that matches one option', () async {
      expect(
          await filter(flavours, options: _plain('3\n', _Out())), 'Strawberry');
      expect(await filter(flavours, options: _plain('choc\n', _Out())),
          'Chocolate');
    }, timeout: _timeout);

    test('asks again when text matches several options', () async {
      final out = _Out();
      expect(
          await filter(flavours,
              title: 'Flavour', options: _plain('a\nvan\n', out)),
          'Vanilla');
      expect(
        await _noEscapes(out),
        'Flavour\n1. Vanilla\n2. Chocolate\n3. Strawberry\n'
        'Enter a number: a\n'
        'Enter a number from 1 to 3, or text that matches one option.\n'
        'Enter a number: van\n',
      );
    }, timeout: _timeout);
  });

  group('spin', () {
    test('writes a start line and a done line', () async {
      final out = _Out();
      final v = await spin(Future.value(42),
          label: 'Working…', options: _plain('', out));
      expect(v, 42);
      expect(await _noEscapes(out), 'Working…\n✓ Working\n');
    }, timeout: _timeout);

    test('writes the error and rethrows it', () async {
      final out = _Out();
      await expectLater(
        spin<int>(Future.error(StateError('boom')),
            label: 'Deploy', options: _plain('', out)),
        throwsA(isA<StateError>()),
      );
      expect(await _noEscapes(out), 'Deploy…\n✗ Deploy: Bad state: boom\n');
    }, timeout: _timeout);
  });

  test('pager writes the content as it is', () async {
    final out = _Out();
    await pager('line 1\nline 2', options: _plain('', out));
    expect(await _noEscapes(out), 'line 1\nline 2\n');
  }, timeout: _timeout);

  group('Form.run', () {
    Form build() => Form([
          Group([
            Field.note(title: 'Welcome', description: 'Three questions.'),
            Field.input(key: 'name', title: 'Name', placeholder: 'your name'),
            Field.select(
                key: 'lang', title: 'Language', options: ['dart', 'go']),
          ], title: 'Basics'),
          Group([
            Field.selectOf<String>(
              key: 'fw',
              titleFor: (v) => 'Framework for ${v.get<String>('lang')}',
              optionsFor: (v) => v.get<String>('lang') == 'go'
                  ? const [Option('gin', 'gin'), Option('echo', 'echo')]
                  : const [Option('shelf', 'shelf'), Option('frog', 'frog')],
            ),
            Field.confirm(
              key: 'cgo',
              title: 'Use cgo?',
              hidden: (v) => v.get<String>('lang') != 'go',
            ),
            Field.multiSelect(
                key: 'extras',
                title: 'Extras',
                options: ['lint', 'ci', 'docker']),
          ]),
        ]);

    Stream<List<int>> keys(List<String> keys) => Stream.fromIterable([
          for (final k in keys)
            switch (k) {
              'tab' => [0x09],
              'down' => [0x1b, 0x5b, 0x42],
              'space' => [0x20],
              _ => utf8.encode(k),
            }
        ]);

    Future<Map<String, Object?>?> tui(List<String> keyList) async =>
        (await build().run(options: [
          withoutRenderer(),
          withEnvironment(const {}),
          withInput(keys(keyList)),
          withOutput(_Out().sink),
        ]))
            ?.toMap();

    test('plain and terminal runs return equal values', () async {
      // Go: the hidden confirm shows, and the framework options follow.
      final out = _Out();
      final plain =
          await build().run(options: _plain('Ada\n2\n2\ny\n1,3\n', out));
      final terminal = await tui([
        'A', 'd', 'a', 'tab', 'down', 'tab', 'down', 'tab', 'y', 'tab', //
        'space', 'down', 'down', 'space', 'tab',
      ]);
      expect(plain!.toMap(), terminal);
      expect(terminal, {
        'name': 'Ada',
        'lang': 'go',
        'fw': 'echo',
        'cgo': true,
        'extras': ['lint', 'docker'],
      });
      expect(
        await _noEscapes(out),
        'Basics\n'
        'Welcome\nThree questions.\n'
        'Name (your name): Ada\n'
        'Language\n1. dart\n2. go\nEnter a number [1]: 2\n'
        'Framework for go\n1. gin\n2. echo\nEnter a number [1]: 2\n'
        'Use cgo? (y/N) y\n'
        'Extras\n1. lint\n2. ci\n3. docker\n'
        'Enter numbers separated by commas: 1,3\n',
      );

      // Dart: the confirm stays hidden and is left out of the values.
      final plainDart =
          await build().run(options: _plain('Ada\n\n2\n\n', _Out()));
      final terminalDart =
          await tui(['A', 'd', 'a', 'tab', 'tab', 'down', 'tab', 'tab']);
      expect(plainDart!.toMap(), terminalDart);
      expect(terminalDart, {
        'name': 'Ada',
        'lang': 'dart',
        'fw': 'frog',
        'extras': <String>[],
      });
    }, timeout: _timeout);

    test('validators ask again with their message', () async {
      final out = _Out();
      final values = await Form([
        Group([
          Field.input(
            key: 'name',
            title: 'Name',
            initial: 'x',
            validate: (v) => v.length < 2 ? 'Too short' : null,
          ),
        ]),
      ]).run(options: _plain('\nAda\n', out));
      expect(values!.get<String>('name'), 'Ada');
      expect(await _noEscapes(out), 'Name [x]: \n✗ Too short\nName [x]: Ada\n');
    }, timeout: _timeout);

    test('multi-select honours its limit and keeps defaults on empty input',
        () async {
      final out = _Out();
      final values = await Form([
        Group([
          Field.multiSelect(
              key: 'm', title: 'M', options: ['a', 'b', 'c'], limit: 1),
          Field.multiSelect(
              key: 'd', title: 'D', options: ['a', 'b'], initial: {'b'}),
        ]),
      ]).run(options: _plain('1,2\n9\n3\n\n', out));
      expect(values!.toMap(), {
        'm': ['c'],
        'd': ['b'],
      });
      expect(
        await _noEscapes(out),
        'M\n1. a\n2. b\n3. c\n'
        'Enter numbers separated by commas (up to 1): 1,2\nChoose at most 1.\n'
        'Enter numbers separated by commas (up to 1): 9\n'
        'Enter numbers from 1 to 3, like 1,3.\n'
        'Enter numbers separated by commas (up to 1): 3\n'
        'D\n1. a\n2. b\nEnter numbers separated by commas [2]: \n',
      );
    }, timeout: _timeout);

    test('end of input cancels the form', () async {
      expect(await build().run(options: _plain('Ada\n', _Out())), isNull);
    }, timeout: _timeout);
  });

  group('detection', () {
    // In plain mode the helper writes its question; with no renderer, the
    // terminal path writes nothing.
    Future<bool> isPlain(List<ProgramOption> extra) async {
      final out = _Out();
      await promptConfirm('Q', options: [
        withoutRenderer(),
        withInput(Stream.value(utf8.encode('y\n'))),
        withOutput(out.sink),
        ...extra,
      ]);
      return (await out.text()).contains('(Y/n)');
    }

    test('custom input or output keeps the terminal UI', () async {
      expect(await isPlain([withEnvironment(const {})]), isFalse);
    }, timeout: _timeout);

    test('forcing on and off', () async {
      expect(
          await isPlain([withEnvironment(const {}), withPlainMode()]), isTrue);
      expect(
          await isPlain([
            withEnvironment(const {'DART_TUI_ACCESSIBLE': '1'}),
            withPlainMode(false),
          ]),
          isFalse);
    }, timeout: _timeout);

    test('DART_TUI_ACCESSIBLE and ACCESSIBLE turn it on', () async {
      expect(
          await isPlain([
            withEnvironment(const {'DART_TUI_ACCESSIBLE': '1'})
          ]),
          isTrue);
      expect(
          await isPlain([
            withEnvironment(const {'ACCESSIBLE': '1'})
          ]),
          isTrue);
      expect(
          await isPlain([
            withEnvironment(const {'ACCESSIBLE': '0'})
          ]),
          isFalse);
    }, timeout: _timeout);

    test('the output rule is shared with colour detection', () {
      expect(isPlainOutput(const {}, true), isFalse);
      expect(isPlainOutput(const {}, false), isTrue);
      expect(isPlainOutput(const {'TERM': 'dumb'}, true), isTrue);
      expect(
          detectColorProfile(
              environment: const {'TERM': 'dumb'}, isTerminal: true),
          ColorProfile.noColor);
    });

    test('real stdio that is not a terminal turns it on', () async {
      // pager would wait for `q` in the terminal UI; plain mode returns.
      await pager('', options: [withEnvironment(const {})]);
    },
        timeout: _timeout,
        skip: stdin.hasTerminal && stdout.hasTerminal
            ? 'needs stdin or stdout that is not a terminal'
            : false);

    test('TERM=dumb turns it on with real stdio', () async {
      await pager('', options: [
        withEnvironment(const {'TERM': 'dumb'})
      ]);
    }, timeout: _timeout);
  });

  group('custom Program with plain output', () {
    test('renders nothing while running, then the final frame once', () async {
      final out = _Out();
      final previous = Style.defaultProfile;
      addTearDown(() => Style.defaultProfile = previous);
      final program = Program(options: [
        withPlainMode(),
        withEnvironment(const {}),
        withInput(Stream.fromIterable([
          [0x2b],
          [0x2b],
          [0x71],
        ])),
        withOutput(out.sink),
      ]);
      await program.run(_Counter(0));
      expect(await _noEscapes(out), 'printed 1\nprinted 2\ncount: 2\n');
    }, timeout: _timeout);
  });
}

final class _Counter extends Model {
  _Counter(this.n);
  final int n;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    if (msg.key == 'q') return (this, () => QuitMsg());
    return (_Counter(n + 1), () => PrintLineMsg('printed ${n + 1}'));
  }

  @override
  View view() => newView('\x1b[1mcount: $n\x1b[0m');
}
