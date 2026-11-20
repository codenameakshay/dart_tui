# __name__

A command-line app with commands, made with
[dart_tui](https://pub.dev/packages/dart_tui).

## Run

```bash
dart run __name__ --help
dart run __name__ greet Ada
dart run __name__ count --to 5
```

## Test

```bash
dart test
```

The tests run the commands in-process and read their output from a
`CaptureSink` (`package:dart_tui/testing.dart`).

## Install and complete

```bash
dart pub global activate --source path .
__name__ completion install    # Tab completion for bash, zsh or fish
```

## Next steps

- Add a command: copy `GreetCommand` in `lib/__name__.dart` and register it
  in `AppRunner`.
- Use `logger.tasks` for a list of steps that run with spinners.
- Read the guides at https://dart-tui.vercel.app.
