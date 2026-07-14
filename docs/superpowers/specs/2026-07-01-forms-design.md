# Forms subsystem (huh-style) — Design Spec

**Status:** approved design, ready for implementation planning
**Target release:** dart_tui 1.4.0
**Author:** brainstormed with the maintainer, 2026-07-01

## Goal

A composable, immutable, Elm-style **forms** subsystem for dart_tui — the equivalent of Charm's [huh](https://github.com/charmbracelet/huh). It systematizes what apps currently hand-roll (see `example/textinputs.dart`: manual focus cycling, per-field plumbing, submit handling) into a declarative `Form` of typed fields with validation, multi-page wizards, and dynamic/conditional fields.

Full huh parity is in scope: field types, groups/wizard pages, per-field validation with inline errors, dynamic (conditional/computed) fields, and theming.

## Framing decisions (locked)

1. **Scope:** full parity — fields + groups/wizard + dynamic fields + theming.
2. **Value binding:** key-based. Each field has a string `key`; the `Form` is immutable and exposes a values map. Dynamic fields are pure functions of the current `FormValues`. No pointer/`Ref` binding.
3. **Consumption:** the `Form` is itself a `TeaModel` (embeddable via `update`/`view`, exposing `submitted`/`cancelled`/`values`), **and** a one-shot `form.run()` helper wraps `Program.runForResult` (like `gum`/`prompts`), with a `programOptions` seam for headless testing.
4. **Field internals:** hybrid — reuse `TextInputModel` (input/password), `TextAreaModel` (multiline text), `FilePickerModel` (file); build small fresh editors for `select`, `multiSelect`, `confirm`, `note`.
5. **Decision A (multiline Enter):** in a multiline `text` field, `Enter` inserts a newline; `Tab` (or `Ctrl+D`) advances. In all single-value fields, `Enter` advances.
6. **Decision B (hidden fields in result):** hidden fields are **excluded** from `FormValues` (`get('regions')` is `null` if the field was never shown).

## Public API

```dart
final form = Form([
  Group([
    Field.input(key: 'name', title: 'Service name',
        validate: (v) => v.contains(' ') ? 'no spaces allowed' : null),
    Field.select(key: 'runtime', title: 'Runtime',
        options: ['Dart', 'Go', 'Node'], initial: 'Dart'),
    Field.confirm(key: 'deploy', title: 'Deploy now?', initial: true),
  ], title: 'Basics'),

  Group([
    Field.multiSelect(key: 'regions', title: 'Regions',
        options: ['iad', 'fra', 'sfo']),
    Field.note(title: 'Review', description: 'Press enter to submit.'),
  ], title: 'Deploy', hidden: (v) => v.get<bool>('deploy') != true),
], styles: FormStyles.defaults);

// one-shot:
final values = await form.run();            // FormValues? — null if cancelled
final name    = values?.get<String>('name');
final regions = values?.get<List<String>>('regions');

// embedded (inside your own TeaModel):
(Model, Cmd?) update(Msg m) {
  final (f, cmd) = form.update(m);
  final next = f as Form;
  if (next.submitted) return (Done(next.values!), null);
  if (next.cancelled) return (this, () => quit());
  return (copyWith(form: next), cmd);
}
View view() => form.view();
```

### Field factories (`abstract final class Field`)

Each returns a `FormField`. Common named params: `key` (required except `note`), `title` (static) **or** `titleFor: (FormValues) => String` (dynamic; mutually exclusive with `title`), `description`, `hidden: (FormValues) => bool`.

- `Field.input({key, title/titleFor, description, String initial = '', String placeholder = '', String? Function(String)? validate, hidden})` → value `String`.
- `Field.password({...same as input...})` → value `String`; editor renders bullets (`EchoMode.password`).
- `Field.text({key, ..., String initial = '', int maxHeight = 6})` → value `String` (may contain `\n`).
- `Field.file({key, ..., String? initialDir, Set<String> extensions = const {}})` → value `String?` (selected path).
- `Field.select({key, ..., required List<String> options, String? initial, String? Function(String)? validate})` → value `String`.
- `Field.selectOf<T>({key, ..., required List<Option<T>> options, List<Option<T>> Function(FormValues)? optionsFor, T? initial, String? Function(T)? validate})` → value `T`.
- `Field.multiSelect({key, ..., required List<String> options, Set<String> initial = const {}, int? limit})` → value `List<String>`.
- `Field.multiSelectOf<T>({key, ..., required List<Option<T>> options, List<Option<T>> Function(FormValues)? optionsFor, Set<T> initial = const {}, int? limit})` → value `List<T>`.
- `Field.confirm({key, title/titleFor, description, bool initial = false, String affirmative = 'Yes', String negative = 'No', hidden})` → value `bool`.
- `Field.note({title/titleFor, description, hidden})` → no key, no value.

Dynamic `options` is available only on `selectOf`/`multiSelectOf` via `optionsFor`; static `options` and `optionsFor` are mutually exclusive. `select`/`multiSelect` (String) accept static `options` only (dynamic-option String forms use `selectOf`/`multiSelectOf`).

## Data model / types

`lib/src/forms/` with a `lib/src/forms.dart` barrel, exported from `lib/dart_tui.dart`.

### `FormValues`
```dart
final class FormValues {
  const FormValues(this._map);
  final Map<String, Object?> _map;
  T? get<T>(String key) => _map[key] as T?;
  bool has(String key) => _map.containsKey(key);
  Map<String, Object?> toMap() => Map.unmodifiable(_map);
}
```
Contains one entry per **currently-visible, keyed** field, keyed by `key`, holding its current typed value. Hidden fields and `note` fields contribute no entry (Decision B).

### `Option<T>`
```dart
final class Option<T> {
  const Option(this.label, this.value);
  final String label;
  final T value;
}
```

### `FormStyles`
Follows the per-component `*Styles` convention (Catppuccin Mocha defaults). Slots: `title`, `activeTitle`, `description`, `error`, `cursor`, `option`, `selectedOption`, `checkedBox`, `uncheckedBox`, `help`, `pageIndicator`. `FormStyles.defaults` provided.

### `sealed class FormField`
```dart
sealed class FormField {
  String? get key;                              // null for note
  bool get acceptsInput;                        // false for note
  bool isHidden(FormValues values);             // resolves static/dynamic
  String titleText(FormValues values);          // resolves static/dynamic
  String? descriptionText(FormValues values);
  Object? get value;                            // current typed value (null for note)
  String? get error;                            // last validation error, or null
  String? validate();                           // run validator against current value → message|null
  FormField updateEditor(Msg msg);              // delegate a key to the field's editor → new field
  FormField recompute(FormValues values);       // refresh dynamic options; clamp selection; returns new field
  FormField withError(String? error);
  String render(bool active, FormStyles styles, FormValues values);
}
```
Concrete (private) subclasses, one per factory: `_InputField` (wraps `TextInputModel`; `password` = same with `EchoMode.password`), `_TextField` (`TextAreaModel`), `_FileField` (`FilePickerModel`), `_SelectField<T>`, `_MultiSelectField<T>`, `_ConfirmField`, `_NoteField`. Text-ish fields delegate `updateEditor` to the wrapped component and read `.value`; the fresh editors hold their own minimal state (selected index / selected set / bool).

### `Group`
```dart
final class Group {
  Group(List<FormField> fields, {String? title, bool Function(FormValues)? hidden});
}
```

### `Form extends TeaModel implements OutcomeModel<FormValues>`
```dart
final class Form extends TeaModel implements OutcomeModel<FormValues> {
  Form(List<Group> groups, {FormStyles styles = FormStyles.defaults, /* internal: indices, flags */});

  bool get submitted;
  bool get cancelled;
  FormValues? get values;      // computed from visible keyed fields
  @override FormValues? get outcome; // == values when submitted, else null

  Future<FormValues?> run({ProgramOptions programSettings, List<ProgramOption> programOptions});
}
```
`run()` builds a `Program(...).runForResult(this)`; returns `values` on submit, `null` on cancel (cancel issues a quit `Cmd`, mirroring the `prompts` fix so it never hangs). Immutable: `update` returns a new `Form`; internal navigation state (group/field indices, per-field editor state, submitted/cancelled) is carried via a private constructor.

## Behavior

### Value collection
`values`/`outcome` are computed on demand: walk visible groups → visible keyed fields → `{key: field.value}`. Recomputed whenever read; the submitted snapshot is taken at submit time.

### Focusability
A field is a **focus target** iff `acceptsInput && !isHidden(values)`. `note` fields and hidden fields render but are never focused. A group with no focus targets (e.g. a note-only "review" page) still renders; `Enter`/`Tab` advances past it (acts as a confirm/submit page).

### Key map (Form-level, before delegating to the active field)
- `Tab` → advance. `Shift+Tab` → back.
- `Enter` → advance, **except** when the active field is a multiline `text` field (then it delegates to the editor as a newline). `Ctrl+D` always advances (lets `text` fields advance).
- `Esc` / `Ctrl+C` → cancel (`cancelled = true`, issue quit `Cmd`).
- Any other key → `activeField.updateEditor(msg)`; the resulting field replaces the active one; then `recompute` runs across all fields (see Dynamic).

Active-field editor keys (delegated): input/password — full `TextInputModel` handling incl. readline; text — `TextAreaModel` handling (arrows, ctrl+k/u/w, Enter=newline); file — `FilePickerModel`; select — `↑/↓` or `←/→` change selection; multiSelect — `↑/↓` move highlight, `Space` toggle (respect `limit`); confirm — `←/→` or `y`/`n` toggle.

### advance() / back()
- **advance:** run `activeField.validate()`. If it returns a message → set that field's `error`, do not move (stay on field). Else clear its error and move focus to the next focus target: next visible focusable field in the current group after the current index; else the first focus target of the next visible group (entering a focus-less group lands on its "advance to continue" state); else (past the last field of the last visible group) → **submit** (`submitted = true`, snapshot `values`).
- **back:** previous focus target: previous visible focusable field in the group; else the last focus target of the previous visible group. No validation on back. No-op at the very first field.

### Validation
`String? Function(value)` per field (typed to the field's value type). Runs on `advance` and again for every field on `submit` (submit re-validates the whole form; the first field with an error becomes active and submit is blocked). Inline error rendered via `FormStyles.error` beneath the field.

### Dynamic recompute
After any change that can alter values (an editor update, an advance), the Form:
1. Rebuilds `FormValues` from current visible fields.
2. Calls `field.recompute(values)` on every field — refreshes dynamic `optionsFor` results and clamps a `select`/`multiSelect` selection if its options shrank (drop selections no longer present; `select` clamps index into range).
3. Re-resolves `hidden` for fields and groups. If the **active** field is now hidden, focus jumps to the next focus target (or the previous one if none follow).

`titleFor`/`descriptionFor` are resolved lazily in `render`/collection from the passed `values` (no stored state).

### Wizard / groups
- Multi-visible-group form: renders **one group at a time** (the active group), with a `Group N/M` (or group `title`) indicator via `FormStyles.pageIndicator`. Advancing past a group's last field moves to the next visible group; `back` from a group's first field moves to the previous visible group's last field.
- Single-visible-group form: renders that group's fields with no page indicator.
- A group whose `hidden(values)` is true is skipped entirely (nav + render).

### Rendering (`view()`)
Active group's title (if any) + page indicator; each non-hidden field rendered via `field.render(active, styles, values)` with the focused field highlighted (active title style, cursor), its inline error beneath it if any; a footer help line (`tab next · shift+tab back · enter submit · esc cancel`, adjusted for `text` fields). For focused input/text fields, `View.cursor` is set (delegated from the wrapped editor, offset by the field's render position) so the terminal cursor lands correctly.

## Error handling & edge cases

- **Construction asserts:** duplicate non-null `key`s across the whole form → assert/throw; a `Form` with zero groups or a group with zero fields → assert/throw.
- **Empty visible form** (everything hidden): `run()` submits immediately with an empty `FormValues`.
- **Option shrink:** handled by `recompute` (clamp/drop).
- **`initial` not among options:** `select` falls back to index 0; `multiSelect` drops unknown initials.
- **`limit` on multiSelect:** toggling beyond `limit` is a no-op (can't check more).
- **Blocked submit:** a failing validator keeps the form open with the offending field active and its error shown.

## File layout

- `lib/src/forms/form.dart` — `Form`, `Group`, `FormValues`, `run()`, navigation/validation/dynamic logic.
- `lib/src/forms/field.dart` — `Field` factory, `sealed FormField` + concrete subclasses, `Option<T>`.
- `lib/src/forms/editors.dart` — fresh `select`/`multiSelect`/`confirm` editor state + rendering (kept out of `field.dart` to keep files focused; `note` is trivial and lives in `field.dart`).
- `lib/src/forms/form_styles.dart` — `FormStyles` + Catppuccin defaults.
- `lib/src/forms.dart` — barrel; add `export 'src/forms.dart';` to `lib/dart_tui.dart`.
- `example/form.dart` + `example/tapes/form.tape` — the deploy-wizard demo above; README + example-README entries.
- `test/forms/` — `field_test.dart`, `form_nav_test.dart`, `form_dynamic_test.dart`, `form_run_test.dart`.

## Testing strategy

- **Per-field (`field_test.dart`):** each field type — initial value, `updateEditor` for its keys, `value` extraction, `validate`, `render` (active/inactive), `recompute` clamping. Reuse patterns from existing component tests.
- **Form navigation (`form_nav_test.dart`):** tab/shift+tab/enter across fields and across groups; note/hidden fields skipped; note-only review group; `text` field Enter=newline vs Tab advance; back at first field is a no-op; validation blocks advance and submit; submit → correct `FormValues`; cancel → `cancelled`.
- **Dynamic (`form_dynamic_test.dart`):** `hidden` toggling shows/hides fields and whole groups; active-field-becomes-hidden refocuses; `optionsFor` refresh + selection clamp; `titleFor` resolves from current values; hidden fields excluded from `values` (Decision B).
- **One-shot (`form_run_test.dart`):** drive `form.run()` headlessly via the `programOptions` seam (key injection like `prompts`/`gum`): fill + submit → values; esc → null.
- Coverage stays ≥ 90% (the CI gate added in 1.3.0). New editors and dynamic paths must be covered or `// coverage:ignore`-justified.

## Out of scope (future)

- Accessibility / screen-reader mode (huh's accessible mode).
- Async validators (validators are synchronous `String? Function(value)`).
- Free-form field layout / columns (fields are a vertical list within a group).
- Typed `Option<T>` values beyond `selectOf`/`multiSelectOf` (e.g. records as keys).
