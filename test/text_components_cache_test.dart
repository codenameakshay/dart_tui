import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('text input keeps cursor-only copies correct after warming caches', () {
    final model = TextInputModel(
      value: '你a',
      cursorPos: 1,
      label: 'X',
      suggestions: const ['你abc'],
    );
    final warmed = model.view();
    final moved = model.copyWith(cursorPos: 0).view();

    expect(warmed.content, moved.content);
    expect(warmed.cursor?.x, 4);
    expect(moved.cursor?.x, 2);
  });

  test('text input invalidates grapheme and suggestion caches on value edits',
      () {
    final model = TextInputModel(
      value: 'ap',
      cursorPos: 2,
      suggestions: const ['apple'],
    )..view();
    final edited = model.copyWith(value: '你', cursorPos: 1);

    expect(edited.currentSuggestion, isNull);
    expect(edited.view().cursor?.x, 2);
  });

  test('text input freezes suggestions passed to copyWith', () {
    final suggestions = ['apple'];
    final model = TextInputModel().copyWith(suggestions: suggestions);
    suggestions[0] = 'changed';

    expect(model.suggestions, ['apple']);
  });

  test('text input copyWith preserves suggestion index validation', () {
    expect(
      () => TextInputModel().copyWith(suggestionIndex: -1),
      throwsA(isA<AssertionError>()),
    );
  });

  test('form observes caller-owned field list mutations', () {
    final fields = <FormField>[
      Field.input(key: 'name', initial: 'before'),
    ];
    final form = Form([Group(fields)]);
    form.values;
    form.view();

    fields[0] = Field.input(key: 'name', initial: 'after');

    expect(form.values.get<String>('name'), 'after');
    expect(form.view().content, contains('after'));
  });
}
