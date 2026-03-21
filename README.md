# dart_tui

Elm-style terminal applications in Dart, inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea): a **`Model`** with **`init`**, **`update`**, and declarative **`View`**, plus async **`Cmd`**s and a **`Program`** runtime.

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
fvm dart run example/shopping_list.dart
```

**All components** (shopping list, spinner, progress, text input, select list, `TuiStyle`, prompts info) in one interactive menu:

```bash
fvm dart run example/showcase.dart
```

**Detailed one-file API tour** (style, components, commands, typed messages):

```bash
fvm dart run example/all_features.dart
```

**Prompts** (`promptSelect` / `promptConfirm` / `promptInput`) each run their own `Program`; chain them from a script:

```bash
fvm dart run example/prompts_chain.dart
```

Note: prompt demos are interactive TTY flows; piped stdin can produce partial/early input consumption.

## Breaking Changes (Current Branch)

- Removed legacy Go-style API aliases (`Batch`, `Sequence`, `Quit`, `Println`, `WithInput`, etc.).
- Use canonical lowercase APIs instead (`batch`, `sequence`, `quit`, `println`, `withInput`, etc.).
- `request*` commands now emit real terminal protocol queries and rely on decoder responses.

For deterministic interactive smoke checks, run:

```bash
python3 tool/pty_examples_smoke.py
```

## Core concepts

| Concept | Role |
|--------|------|
| [`Model`](lib/src/model.dart) | `init()` → optional `Cmd`; `update(Msg)` → next model + optional `Cmd`; `view()` → [`View`](lib/src/view.dart) |
| [`Msg`](lib/src/msg.dart) | `KeyPressMsg`, `KeyReleaseMsg`, `WindowSizeMsg`, `TickMsg`, `PasteMsg`, `FocusMsg`, `QuitMsg`, … |
| [`Cmd`](lib/src/cmd.dart) | `FutureOr<Msg?>` factory; `batch`, `sequence`, `tick`, `every`, request/clipboard/raw/print commands |
| [`Program`](lib/src/program.dart) | Event loop, terminal restore, optional `tickInterval` for animations |

Key input is read from stdin on the **main isolate** via a non-blocking byte stream and the same key mapping as [`Console.readKey`](https://pub.dev/documentation/dart_console/latest/dart_console/Console/readKey.html) (see `lib/src/key_buffer_parser.dart`). Stdin is not reliably available to secondary isolates, so input must stay on the main isolate. `ProgramOptions.tickInterval` schedules [TickMsg](lib/src/msg.dart) on a timer; because the loop is not blocked on synchronous reads, ticks run between key events for spinners and similar animations.

## Prompts (optional)

Imperative helpers for scripts:

- `promptSelect(choices)` → `Future<String?>`
- `promptConfirm(question)` → `Future<bool?>`
- `promptInput(label)` → `Future<String?>`

## Components

Under `lib/src/bubbles/`: [`SpinnerModel`](lib/src/bubbles/spinner.dart), [`ProgressModel`](lib/src/bubbles/progress.dart), [`TextInputModel`](lib/src/bubbles/text_input.dart), [`SelectListModel`](lib/src/bubbles/select_list.dart), [`PaginatorModel`](lib/src/bubbles/paginator.dart), [`HelpModel`](lib/src/bubbles/help.dart), plus composable [`Style`](lib/src/bubbles/style.dart) and compatibility [`TuiStyle`](lib/src/bubbles/style.dart) helpers.

## Debugging

Set `ProgramOptions(logFile: File('debug.log'))` to append rendered frames (similar in spirit to Bubble Tea’s file logging).

## License

MIT. This project is inspired by Bubble Tea; see [LICENSE](LICENSE) for third-party attribution.
