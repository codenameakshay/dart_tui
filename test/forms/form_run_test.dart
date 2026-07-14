import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

Stream<List<int>> _seq(List<List<int>> chunks) => Stream.fromIterable(chunks);
List<ProgramOption> _opts(List<List<int>> chunks) =>
    [withoutRenderer(), withInput(_seq(chunks))];
const _enter = [0x0d];
const _ctrlC = [0x03];
const _timeout = Timeout(Duration(seconds: 5));

void main() {
  test('collects values and submits on enter (single field)', () async {
    final form = Form([
      Group([Field.confirm(key: 'ok', title: 'OK?', initial: true)]),
    ]);
    final values = await form.run(programOptions: _opts([_enter]));
    expect(values, isNotNull);
    expect(values!.get<bool>('ok'), true);
  }, timeout: _timeout);

  test('ctrl+c cancels → null', () async {
    final form = Form([
      Group([Field.input(key: 'name', title: 'Name')]),
    ]);
    expect(await form.run(programOptions: _opts([_ctrlC])), isNull);
  }, timeout: _timeout);

  test('outcome is null until submitted; values reflect fields', () {
    final form = Form([
      Group([Field.confirm(key: 'ok', title: 'OK?', initial: false)]),
    ]);
    expect(form.outcome, isNull);
    expect(form.values.get<bool>('ok'), false);
  });
}
