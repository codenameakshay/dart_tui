# dart_tui

Elm-style terminal applications in Dart, inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea): a **`TeaModel`** with **`init`**, **`update`**, and **`view`**, plus async **`Cmd`**s and a **`Program`** runtime.

Compared to Flutter-like TUIs such as [nocterm](https://pub.dev/packages/nocterm), `dart_tui` keeps state in a single model and uses explicit **`Msg`** values (keys, window size, ticks) instead of `setState()` and widgets.

## Install

```yaml
dependencies:
  dart_tui: ^0.1.0
```

## Quick start

```dart
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(MyModel());
}
```

See [example/shopping_list.dart](example/shopping_list.dart) for the Bubble Tea shopping-list tutorial ported to Dart.

Run it:

```bash
dart run example/shopping_list.dart
```

## Core concepts

| Concept | Role |
|--------|------|
| [`TeaModel`](lib/src/model.dart) | `init()` → optional `Cmd`; `update(Msg)` → next model + optional `Cmd`; `view()` → `String` |
| [`Msg`](lib/src/msg.dart) | `KeyMsg`, `WindowSizeMsg`, `TickMsg`, `CompoundMsg`, `QuitMsg`, … |
| [`Cmd`](lib/src/cmd.dart) | `Future<Msg?>` factory; `batch`, `sequence`, `tick` |
| [`Program`](lib/src/program.dart) | Event loop, terminal restore, optional `tickInterval` for animations |

Key input is read via a short-lived [`Isolate.run`](https://api.dart.dev/dart-isolate/Isolate/run.html) around `dart_console` so timers can fire between keystrokes when `ProgramOptions.tickInterval` is set.

## Prompts (optional)

Imperative helpers for scripts:

- `promptSelect(choices)` → `Future<String?>`
- `promptConfirm(question)` → `Future<bool?>`
- `promptInput(label)` → `Future<String?>`

## Components (starter set)

Under `lib/src/bubbles/`: [`SpinnerModel`](lib/src/bubbles/spinner.dart), [`ProgressModel`](lib/src/bubbles/progress.dart), [`TextInputModel`](lib/src/bubbles/text_input.dart), [`SelectListModel`](lib/src/bubbles/select_list.dart), and minimal [`TuiStyle`](lib/src/bubbles/style.dart) ANSI helpers.

## Debugging

Set `ProgramOptions(logFile: File('debug.log'))` to append rendered frames (similar in spirit to Bubble Tea’s file logging).

## License

MIT. This project is inspired by Bubble Tea; see [LICENSE](LICENSE) for third-party attribution.
