import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:test/test.dart';

final class _Output implements StreamConsumer<List<int>> {
  final bytes = <int>[];
  late final sink = IOSink(this);
  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach(bytes.addAll);
  @override
  Future<void> close() async {}
  Future<String> text() async {
    await sink.flush();
    return utf8.decode(bytes);
  }
}

List<ProgramOption> _plain(_Output out, [String input = '1\n']) => [
      withPlainMode(),
      withEnvironment(const {}),
      withInput(Stream.value(utf8.encode(input))),
      withOutput(out.sink),
    ];

void main() {
  test('plain helpers strip styled headings, labels, content and errors',
      () async {
    final out = _Output();
    const styled = '\x1b[31mred\x1b[0m';
    expect(await promptSelect([styled], title: styled, options: _plain(out)),
        styled);
    expect(await promptInput(styled, options: _plain(out, 'ok\n')), 'ok');
    expect(await promptConfirm(styled, options: _plain(out, 'y\n')), isTrue);
    expect(await filter([styled], title: styled, options: _plain(out)), styled);
    await pager('$styled\x1b', options: _plain(out));
    await spin(Future.value(1), label: styled, options: _plain(out));
    await expectLater(
      spin(Future<int>.error(StateError(styled)),
          label: styled, options: _plain(out)),
      throwsStateError,
    );
    final text = await out.text();
    expect(text, contains('red'));
    expect(text, isNot(contains('\x1b')));
  });

  test('plain renderer strips incomplete escapes too', () async {
    final out = _Output();
    final renderer = PlainRenderer(out.sink);
    renderer.insertAbove('before\x1b');
    renderer.render(newView('after\x1b['));
    renderer.close();
    renderer.close();
    expect(await out.text(), 'before\nafter[');
  });

  test('withoutRenderer does not enable controls in forced plain mode',
      () async {
    final out = _Output();
    final profile = Style.defaultProfile;
    final background = Style.hasDarkBackground;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = background;
    });
    await Program(options: [
      ..._plain(out, 'q'),
      withoutRenderer(),
    ]).run(_Requests());
    expect(await out.text(), isEmpty);
  });
}

final class _Requests extends Model {
  @override
  Cmd? init() => () => RequestCursorPositionMsg();
  @override
  (Model, Cmd?) update(Msg msg) =>
      (this, msg is KeyMsg ? () => QuitMsg() : null);
  @override
  View view() => newView('frame');
}
