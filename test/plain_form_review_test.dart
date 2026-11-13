import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

final class _Output implements StreamConsumer<List<int>> {
  final bytes = <int>[];
  late final sink = IOSink(this);
  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach(bytes.addAll);
  @override
  Future<void> close() async {}
}

List<ProgramOption> _plain(String answers, _Output output) => [
      withPlainMode(),
      withEnvironment(const {}),
      withInput(Stream.value(utf8.encode(answers))),
      withOutput(output.sink),
    ];

KeyPressMsg _key(KeyCode code) => KeyPressMsg(TeaKey(code: code));

enum _Choice { first, second }

void main() {
  test('stops asking a group that becomes hidden after an answer', () async {
    Form build() => Form([
          Group([
            Field.confirm(key: 'skip', title: 'Skip this group?'),
            Field.input(key: 'hidden', title: 'Must not ask'),
          ], hidden: (v) => v.get<bool>('skip') == true),
          Group([Field.input(key: 'name', title: 'Name')]),
        ]);
    var tui = build();
    tui = tui
        .update(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: 'y')))
        .$1 as Form;
    tui = tui.update(PasteMsg('Ada')).$1 as Form;
    tui = tui.update(_key(KeyCode.enter)).$1 as Form;
    expect(tui.submitted, isTrue);
    final output = _Output();
    final result = await build().run(options: _plain('y\nAda\n', output));
    expect(result?.toMap(), tui.values.toMap());
    await output.sink.flush();
    expect(utf8.decode(output.bytes), isNot(contains('Must not ask')));
  });

  test('empty options submit without reading or calling select validators',
      () async {
    final result = await Form([
      Group([
        Field.selectOf<int>(
          key: 'one',
          options: const [],
          validate: (_) => throw StateError('no value to validate'),
        ),
        Field.multiSelectOf<int>(key: 'many', options: const []),
      ]),
    ]).run(options: [
      withPlainMode(),
      withEnvironment(const {}),
      withInput(null),
      withOutput(_Output().sink),
    ]);
    expect(result!.get<int>('one'), isNull);
    expect(result.get<List<int>>('many'), isEmpty);
  });

  test('newly revealed invalid field consumes input and cancels on EOF',
      () async {
    final output = _Output();
    final result = await Form([
      Group([
        Field.input(
          key: 'required',
          title: 'Required',
          hidden: (v) => v.get<bool>('reveal') != true,
          validate: (v) => v.isEmpty ? 'Required value' : null,
        ),
        Field.confirm(key: 'reveal', title: 'Reveal?'),
      ]),
    ]).run(options: _plain('y\n', output));
    expect(result, isNull);
    await output.sink.flush();
    expect(utf8.decode(output.bytes), contains('Required: '));
  });

  test('typed dynamic choices preserve the runtime value types', () async {
    final output = _Output();
    final result = await Form([
      Group([
        Field.input(key: 'name'),
        Field.selectOf<_Choice>(
          key: 'one',
          titleFor: (v) => 'Choice for ${v.get<String>('name')}',
          optionsFor: (v) => const [
            Option('First', _Choice.first),
            Option('Second', _Choice.second),
          ],
        ),
        Field.multiSelectOf<_Choice>(
          key: 'many',
          optionsFor: (v) => const [
            Option('First', _Choice.first),
            Option('Second', _Choice.second),
          ],
        ),
      ]),
    ]).run(options: _plain('Ada\n2\n1,2\n', output));
    expect(result!.get<_Choice>('one'), _Choice.second);
    expect(result.get<List<_Choice>>('many'), [_Choice.first, _Choice.second]);
    await output.sink.flush();
    expect(utf8.decode(output.bytes), contains('Choice for Ada'));
  });
}
