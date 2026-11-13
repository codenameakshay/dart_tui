import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Runs `form.run()` under the test harness, presses [key], returns the result.
Future<FormValues?> _run(Form form, String key) async {
  final t = TuiTester.run(form.run);
  addTearDown(t.dispose);
  await t.press(key);
  return (await t.done()).value as FormValues?;
}

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
    final values = await _run(form, 'enter');
    expect(values, isNotNull);
    expect(values!.get<bool>('ok'), true);
  });

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

  test('a two-field form, driven as a model, with goldens', () async {
    final t = TuiTester(Form([
      Group([
        Field.input(key: 'name', title: 'Name'),
        Field.confirm(key: 'ok', title: 'Subscribe?', initial: true),
      ]),
    ]));
    addTearDown(t.dispose);
    expectScreen(t.screen, 'test/goldens/form_empty.txt');
    await t.type('Ada');
    await t.press('tab');
    expectScreen(t.screen, 'test/goldens/form_filled.txt');
    await t.press('enter');
    final values = (await t.done()).outcome as FormValues;
    expect(values.get<String>('name'), 'Ada');
    expect(values.get<bool>('ok'), isTrue);
  });

  test('ctrl+c cancels → null', () async {
    final form = Form([
      Group([Field.input(key: 'name', title: 'Name')]),
    ]);
    expect(await _run(form, 'ctrl+c'), isNull);
  });

  test('outcome is null until submitted; values reflect fields', () {
    final form = Form([
      Group([Field.confirm(key: 'ok', title: 'OK?', initial: false)]),
    ]);
    expect(form.outcome, isNull);
    expect(form.values.get<bool>('ok'), false);
  });
}
