# Forms, prompts, and example-build scenarios

These cases pin down behavior for forms and prompt/tool cleanup:

- `selectOf(optionsFor:, initial:)` starts on the matching value when its first
  option list arrives, retains the chosen value when that list is reordered,
  and carries it through an empty list until options return.
- `multiSelectOf` preserves selected values across option reordering and drops
  values that are no longer offered. Multi-select option values must be unique
  in each static or dynamic option list.
- `selectOf` and `multiSelectOf` reject both/neither option providers with an
  `ArgumentError`; `Form` rejects empty forms, empty groups, and duplicate keys
  with an `ArgumentError` even when assertions are disabled.
- Form navigation skips visible groups without inputs, moves off dynamically
  hidden fields/groups, and leaves cancel/submit reachable when all inputs are
  hidden; the view shows a visible note group rather than stale hidden content.
- `promptInput` accepts an emoji as one grapheme and backspace removes that
  grapheme as a unit.
- Form style tests use custom active-title and error styles and assert the
  resulting ANSI sequences. Form navigation tests check rendered focus instead
  of reaching into a test-only index getter.
- The example compile script exits nonzero if any example compilation fails;
  successful all-example compilation remains successful.

Verification commands:

```sh
dart test test/forms test/prompts_test.dart test/gum_test.dart
python3 tool/compile_examples_test.py
dart analyze
```
