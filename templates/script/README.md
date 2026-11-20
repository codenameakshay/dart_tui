# __name__

A script that asks questions in the terminal, made with
[dart_tui](https://pub.dev/packages/dart_tui).

## Run

```bash
dart run
```

Pipe it (`dart run | cat`) or set `ACCESSIBLE=1` to get plain line questions
instead of the terminal UI.

## Test

```bash
dart test
```

The test answers the prompts with `TuiTester` from
`package:dart_tui/testing.dart`.

## Next steps

- Change the questions in `bin/__name__.dart`. `Logger` also has
  `chooseAny`, `progress` and `tasks`.
- Read the guides at https://dart-tui.vercel.app.
