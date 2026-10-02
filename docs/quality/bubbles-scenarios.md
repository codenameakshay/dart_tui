# Bubble regression scenarios

These scenarios capture the behavior fixed in the bubble audit.

## List

- Filter a one-item list until it has no matches, then press down, up, Page Up,
  and Page Down. The model keeps cursor `0`, selection stays `null`, and no
  range error occurs. Filter entry/exit must still work on a truly empty list.
- In filter mode, type `😀` then Backspace. The filter contains one whole emoji,
  then becomes empty; neither operation splits a UTF-16 surrogate pair.
- With descriptions enabled and a mixture of described and undescribed items,
  click the row containing the third item. The selected item matches the visible
  row even though preceding items occupy different row counts.

## File picker

- Open with an out-of-range cursor and zero height. Rendering and Enter handling
  do not throw; height is normalized and entry access is bounded.
- Select a file, then call `copyWith(clearSelected: true)`. Selection becomes
  `null`.
- Load a missing directory. The loaded state displays `Unable to load directory`
  and does not report `(empty)`. Asynchronous results from superseded loads or
  a different model instance remain ignored.

## Canvas

- Paint many layers at the same z-index over one cell. The final cell comes from
  the last paint call, consistently; higher z-index still wins over lower
  z-index regardless of insertion order.

## Verification

Run the focused tests:

```sh
dart test test/list_model_test.dart test/list_mutation_test.dart \
  test/file_picker_test.dart test/file_picker_load_test.dart test/canvas_test.dart
```

Then run static analysis:

```sh
dart analyze lib/src/bubbles/list.dart lib/src/bubbles/file_picker.dart lib/src/bubbles/canvas.dart
```
