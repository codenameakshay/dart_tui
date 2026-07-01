import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg key(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg rune(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));
Form step(Form f, KeyMsg m) => f.update(m).$1 as Form;

void main() {
  test('hidden field is excluded from values and skipped in nav', () {
    var f = Form([
      Group([
        Field.confirm(key: 'deploy', title: 'Deploy?', initial: false),
        Field.input(
            key: 'region',
            title: 'Region',
            hidden: (v) => v.get<bool>('deploy') != true),
        Field.input(key: 'tail', title: 'Tail'),
      ]),
    ]);
    expect(f.values.has('region'), isFalse); // hidden → excluded
    f = step(f, key(KeyCode.tab)); // skips hidden 'region' → 'tail'
    f = step(f, rune('t'));
    expect(f.values.get<String>('tail'), 't');
  });

  test('toggling a controller reveals a field and includes it', () {
    var f = Form([
      Group([
        Field.confirm(key: 'deploy', title: 'Deploy?', initial: false),
        Field.select(
            key: 'region',
            title: 'Region',
            options: ['iad', 'fra'],
            hidden: (v) => v.get<bool>('deploy') != true),
      ]),
    ]);
    f = step(f, rune('y')); // deploy = true
    expect(f.values.has('region'), isTrue);
    expect(f.values.get<String>('region'), 'iad');
  });

  test('dynamic optionsFor refreshes and clamps selection', () {
    var f = Form([
      Group([
        Field.input(key: 'q', title: 'Query'),
        Field.selectOf<String>(
            key: 'pick',
            title: 'Pick',
            optionsFor: (v) {
              final q = v.get<String>('q') ?? '';
              return [
                for (final o in ['ant', 'bee', 'cat'])
                  if (o.startsWith(q)) Option(o, o)
              ];
            }),
      ]),
    ]);
    f = step(f, rune('b')); // query 'b' → only 'bee'
    expect(f.values.get<String>('pick'), 'bee');
  });

  test('active field becoming hidden refocuses / is skipped', () {
    var f = Form([
      Group([
        Field.input(key: 'a', title: 'A'),
        Field.confirm(key: 'hideNext', title: 'hide?', initial: true),
        Field.input(
            key: 'b',
            title: 'B',
            hidden: (v) => v.get<bool>('hideNext') == true),
      ]),
    ]);
    f = step(f, key(KeyCode.tab)); // A → hideNext (b hidden)
    f = step(f, key(KeyCode.tab)); // hideNext → submit (b skipped)
    expect(f.submitted, isTrue);
    expect(f.values.has('b'), isFalse);
  });
}
