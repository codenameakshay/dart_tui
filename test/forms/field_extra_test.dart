import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg key(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg rune(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));
const styles = FormStyles.defaults;
const v = FormValues.empty;

void main() {
  test('file field: init loads dir, value=selected, render shows dir',
      () async {
    final dir = Directory.systemTemp.createTempSync('formfile');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.txt').writeAsStringSync('x');

    var f = Field.file(key: 'f', title: 'File', initialDir: dir.path);
    expect(f.value, isNull);
    final cmd = f.init();
    expect(cmd, isNotNull);
    final msg = await cmd!();
    f = f.updateEditor(msg!); // _DirLoadedMsg
    expect(f.render(true, styles, v), contains('File'));
    expect(f.recompute(v), same(f));
  });

  test('confirm: h/l toggle; render; unknown/non-key ignored', () {
    var f = Field.confirm(
        key: 'c', title: 'C?', description: 'sure?', initial: false);
    expect(f.render(true, styles, v), contains('C?'));
    f = f.updateEditor(rune('l'));
    expect(f.value, true);
    f = f.updateEditor(rune('h'));
    expect(f.value, false);
    expect(f.render(false, styles, v), contains('Yes'));
    expect(f.updateEditor(rune('z')).value, false); // unknown key
    expect(f.updateEditor(WindowSizeMsg(1, 1)).value, false); // non-key
  });

  test('select: validate error renders; j moves; empty options no-op', () {
    final withErr = Field.select(
        key: 's',
        title: 'S',
        options: ['a', 'b'],
        validate: (val) => val == 'a' ? 'not a' : null);
    expect(withErr.validate(), 'not a');
    expect(
        withErr.withError('not a').render(true, styles, v), contains('not a'));
    expect(
        Field.select(key: 's', title: 'S', options: ['a', 'b'])
            .updateEditor(rune('j'))
            .value,
        'b');
    final empty = Field.selectOf<int>(key: 'e', title: 'E', options: const []);
    expect(empty.value, isNull);
    expect(empty.updateEditor(key(KeyCode.down)), same(empty));
  });

  test('select: dynamic optionsFor via recompute', () {
    final f = Field.selectOf<String>(
        key: 'p', title: 'P', optionsFor: (vals) => [const Option('x', 'x')]);
    expect(f.recompute(const FormValues({})).value, 'x');
  });

  test('dynamic select resolves its initial value when options arrive', () {
    final f = Field.selectOf<String>(
      key: 'p',
      optionsFor: (_) => const [Option('first', 'a'), Option('second', 'b')],
      initial: 'b',
    );

    expect(f.recompute(FormValues.empty).value, 'b');
  });

  test('dynamic select keeps its chosen value through an empty option set', () {
    final f = Field.selectOf<String>(
      key: 'p',
      optionsFor: (v) => v.get<bool>('available') == true
          ? const [Option('first', 'a'), Option('second', 'b')]
          : const [],
      initial: 'b',
    );

    final empty = f.recompute(const FormValues({'available': false}));
    expect(empty.value, isNull);
    expect(
      empty.recompute(const FormValues({'available': true})).value,
      'b',
    );
  });

  test('dynamic select retains a chosen null value when options change', () {
    var field = Field.selectOf<String?>(
      key: 'p',
      optionsFor: (values) => values.get<bool>('empty') == true
          ? const []
          : values.get<bool>('swap') == true
              ? const [Option('None', null), Option('A', 'a')]
              : const [Option('A', 'a'), Option('None', null)],
      initial: 'a',
    ).recompute(FormValues.empty);

    field = field.updateEditor(key(KeyCode.down)).recompute(FormValues.empty);
    expect(field.value, isNull);
    field = field.recompute(const FormValues({'empty': true}));
    field = field.recompute(const FormValues({'swap': true}));
    expect(field.value, isNull);
    expect(field.render(true, styles, v), contains('(•) None'));
  });

  test('dynamic multi-select retains chosen values across option changes', () {
    final f = Field.multiSelectOf<String>(
      key: 'p',
      optionsFor: (v) => v.get<bool>('remove') == true
          ? const [Option('A', 'a')]
          : v.get<bool>('swap') == true
              ? const [Option('B', 'b'), Option('A', 'a')]
              : const [Option('A', 'a'), Option('B', 'b')],
      initial: {},
    );

    final initialOptions = f.recompute(FormValues.empty);
    final chosen =
        initialOptions.updateEditor(key(KeyCode.down)).updateEditor(rune('x'));
    final reordered = chosen.recompute(const FormValues({'swap': true}));
    expect(reordered.value, ['b']);
    final removed = chosen.recompute(const FormValues({'remove': true}));
    expect(removed.value, isEmpty);
  });

  test('dynamic option fields require exactly one option source', () {
    expect(
      () => Field.selectOf<String>(key: 'x'),
      throwsArgumentError,
    );
    expect(
      () => Field.selectOf<String>(
        key: 'x',
        options: const [],
        optionsFor: (_) => const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => Field.multiSelectOf<String>(key: 'x'),
      throwsArgumentError,
    );
  });

  test('multi-select option values must be unique', () {
    expect(
      () => Field.multiSelectOf<String>(
        key: 'm',
        options: const [Option('first', 'same'), Option('again', 'same')],
      ),
      throwsArgumentError,
    );
    final dynamic = Field.multiSelectOf<String>(
      key: 'm',
      optionsFor: (_) => const [
        Option('first', 'same'),
        Option('again', 'same'),
      ],
    );
    expect(() => dynamic.recompute(FormValues.empty), throwsArgumentError);
  });

  test('multiSelect: k/j, x toggle, render, recompute clamp, empty no-op', () {
    var f = Field.multiSelect(key: 'm', title: 'M', options: ['a', 'b', 'c']);
    f = f.updateEditor(rune('x')); // toggle a
    f = f.updateEditor(key(KeyCode.down)).updateEditor(rune('x')); // b
    f = f.updateEditor(rune('k')); // move up
    expect(f.value, ['a', 'b']);
    expect(f.render(true, styles, v), contains('[x]'));

    final dyn = Field.multiSelectOf<String>(
        key: 'd',
        title: 'D',
        optionsFor: (vals) => [const Option('only', 'x')]);
    expect(dyn.recompute(const FormValues({})).value, isEmpty);

    final empt =
        Field.multiSelectOf<String>(key: 'z', title: 'Z', options: const []);
    expect(empt.updateEditor(rune('x')), same(empt));
  });

  test('multi-select snapshots the caller initial set', () {
    final initial = {'a'};
    final field = Field.multiSelect(
      key: 'm',
      options: ['a', 'b'],
      initial: initial,
    );

    initial.add('b');
    expect(field.value, ['a']);
  });

  test('static multi-select ignores initial values missing from its options',
      () {
    var field = Field.multiSelect(
      key: 'm',
      options: ['valid'],
      initial: {'missing'},
      limit: 1,
    );
    field = field.updateEditor(rune('x'));
    expect(field.value, ['valid']);
  });

  test('note: render active shows title+description; ignores input', () {
    final f = Field.note(title: 'T', description: 'D');
    expect(f.render(true, styles, v), allOf(contains('T'), contains('D')));
    expect(f.updateEditor(rune('a')), same(f));
    expect(f.recompute(v), same(f));
  });

  test('input/text render with description + error', () {
    final i =
        Field.input(key: 'i', title: 'I', description: 'desc').withError('bad');
    expect(
        i.render(false, styles, v), allOf(contains('desc'), contains('bad')));
    final t = Field.text(key: 't', title: 'T').withError('oops');
    expect(t.render(true, styles, v), contains('oops'));
  });
}
