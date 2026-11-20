# __name__

A full-screen terminal app, made with
[dart_tui](https://pub.dev/packages/dart_tui).

## Run

```bash
dart run
```

Move with ↑/↓ (or k/j), check an item with Enter, and quit with q.

## Test

```bash
dart test
```

The tests press keys with `TuiTester` from `package:dart_tui/testing.dart`
and read the screen as text.

## Next steps

- Change the list and the keys in `lib/__name__.dart`. `update` returns the
  next state, and `view` draws it.
- Try other components: `TextInputModel`, `TableModel`, `SpinnerModel`.
- Read the guides at https://dart-tui.vercel.app.
