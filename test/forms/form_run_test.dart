import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

Stream<List<int>> _seq(List<List<int>> chunks) => Stream.fromIterable(chunks);
List<ProgramOption> _opts(List<List<int>> chunks) =>
    [withoutRenderer(), withInput(_seq(chunks))];
const _enter = [0x0d];
const _ctrlC = [0x03];
const _timeout = Timeout(Duration(seconds: 5));

void main() {
  test('form rejects duplicate keys and empty groups at runtime', () {
    expect(() => Form([]), throwsArgumentError);
    expect(
      () => Form([
        Group([Field.input(key: 'x'), Field.confirm(key: 'x')])
      ]),
      throwsArgumentError,
    );
    expect(() => Form([Group([])]), throwsArgumentError);
  });

  test('collects values and submits on enter (single field)', () async {
    final form = Form([
      Group([Field.confirm(key: 'ok', title: 'OK?', initial: true)]),
    ]);
    final values = await form.run(options: _opts([_enter]));
    expect(values, isNotNull);
    expect(values!.get<bool>('ok'), true);
  }, timeout: _timeout);

  test('a paste edits only the active field', () {
    var form = Form([
      Group([
        Field.input(key: 'a'),
        Field.input(key: 'b'),
        Field.text(key: 'c'),
      ]),
    ]);
    form = form.update(PasteMsg('hi')).$1 as Form;
    expect(
      [form.values.get<String>('a'), form.values.get<String>('b')],
      ['hi', ''],
    );
    expect(form.values.get<String>('c'), '');
  });

  test('ctrl+c cancels → null', () async {
    final form = Form([
      Group([Field.input(key: 'name', title: 'Name')]),
    ]);
    expect(await form.run(options: _opts([_ctrlC])), isNull);
  }, timeout: _timeout);

  test('outcome is null until submitted; values reflect fields', () {
    final form = Form([
      Group([Field.confirm(key: 'ok', title: 'OK?', initial: false)]),
    ]);
    expect(form.outcome, isNull);
    expect(form.values.get<bool>('ok'), false);
  });
}
