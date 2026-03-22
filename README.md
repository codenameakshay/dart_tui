# dart_tui

[![pub.dev](https://img.shields.io/pub/v/dart_tui.svg)](https://pub.dev/packages/dart_tui)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Elm-style terminal UI framework for Dart, inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).

Build interactive CLI applications with:

- **Model–Update–View** architecture (same as Elm / Bubble Tea)
- **Async commands** (`Cmd`) for I/O, timers, and process execution
- **Composable components** — spinners, progress bars, text inputs, tables, viewports, and more
- **Cell-level diff rendering** for flicker-free output
- **Synchronized updates** (CSI `?2026`) on supported terminals

---

## Installation

```yaml
dependencies:
  dart_tui: ^1.0.0
```

---

## Quick start

```dart
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(CounterModel());
}

final class CounterModel extends TeaModel {
  CounterModel({this.count = 0});
  final int count;

  @override
  Cmd? init() => tick(const Duration(seconds: 1), (_) => _TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _TickMsg) {
      if (count >= 5) return (this, () => quit());
      return (
        CounterModel(count: count + 1),
        tick(const Duration(seconds: 1), (_) => _TickMsg()),
      );
    }
    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView('Count: $count\n\nPress q to quit.');
}

final class _TickMsg extends Msg {}
```

---

## Core concepts

| Concept | Description |
|---------|-------------|
| `Model` | Immutable state. Implement `init()`, `update(Msg)`, `view()`. |
| `Msg` | Tagged event: key press, window resize, tick, custom data. |
| `Cmd` | `FutureOr<Msg?> Function()` — async side-effect that delivers a message. |
| `View` | Declared output string plus optional cursor, mouse mode, window title, alt-screen flag. |
| `Program` | Runs the event loop; manages terminal raw mode, renderer, and signal handling. |

### Model

```dart
abstract class Model {
  Cmd? init() => null;                     // startup command
  (Model, Cmd?) update(Msg msg);           // state transition
  View view();                             // render
}
```

Return a value from prompt-style flows:

```dart
abstract class OutcomeModel<T> implements Model {
  T? get outcome;  // non-null → program stops and returns this value
}

final result = await Program().runForResult<String>(MyPromptModel());
```

### Cmd

```dart
// Common helpers
Msg quit()
Msg interrupt()
Cmd tick(Duration d, Msg Function(DateTime) fn)      // one-shot delay
Cmd every(Duration d, Msg Function(DateTime) fn)     // wall-clock aligned
Cmd? batch(List<Cmd?> cmds)                          // concurrent
Cmd? sequence(List<Cmd?> cmds)                       // sequential
Cmd execProcess(String exe, List<String> args, {...}) // external process
Cmd println([Object? value])                          // print above TUI
```

### Program options

```dart
Program(
  options: const ProgramOptions(
    altScreen: true,
    hideCursor: true,
    tickInterval: Duration(milliseconds: 100),
    logFile: File('debug.log'),
  ),
  programOptions: [
    withFps(60),
    withCellRenderer(),          // enable cell-level diff renderer
    withFilter((model, msg) {    // intercept/transform messages
      if (msg is QuitMsg) return null; // suppress
      return msg;
    }),
  ],
).run(MyModel());
```

---

## Component library

All components live under `package:dart_tui/dart_tui.dart` (re-exported from `lib/src/bubbles/`).

| Component | Description |
|-----------|-------------|
| `SpinnerModel` | Animated indeterminate spinner driven by `TickMsg` |
| `ProgressModel` | Determinate progress bar (0.0–1.0) |
| `TextInputModel` | Single-line input: cursor, charLimit, EchoMode, validate, suggestions |
| `TextAreaModel` | Multi-line editor with scroll and line-kill commands |
| `SelectListModel` | Vertical list with keyboard cursor |
| `PaginatorModel` | Page indicator (dots or custom label) |
| `TableModel` | Scrollable table with column headers and row cursor |
| `ViewportModel` | Scrollable content pane with soft-wrap |
| `TimerModel` | Countdown timer: `start()`/`stop()`/`reset()`, `remaining`, `finished` |
| `StopwatchModel` | Elapsed time: `start()`/`stop()`/`reset()` |
| `HelpModel` | Compact/full keybinding help UI |
| `KeyMap` / `KeyBinding` | Declarative keybinding registry |
| `FilePickerModel` | Async directory browser with extension filtering |
| `Style` | Lipgloss-inspired text styling: colors, dimensions, alignment, borders |

### Style system

```dart
final title = Style(fg: '#FF5F87', bold: true, width: 40, align: Align.center)
    .render('Hello, World!');

// Layout helpers
final ui = joinHorizontal(AlignVertical.top, [leftPane, rightPane]);
final centered = place(termWidth, termHeight, Align.center, AlignVertical.middle, content);
```

---

## Examples

The `example/` directory contains 41 runnable examples:

| File | What it shows |
|------|---------------|
| `simple.dart` | Tick-driven countdown |
| `window_size.dart` | Terminal dimensions |
| `fullscreen.dart` | Alt-screen mode |
| `set_window_title.dart` | OSC window title |
| `altscreen_toggle.dart` | Toggle alt-screen |
| `vanish.dart` | Single keystroke, no residual output |
| `textinput.dart` | Single-line text input |
| `textinputs.dart` | Multi-field form with Tab focus |
| `textarea.dart` | Multi-line editor |
| `autocomplete.dart` | Input with tab-completion |
| `list_simple.dart` | SelectListModel |
| `list_default.dart` | List with selection state |
| `result.dart` | OutcomeModel returning a value |
| `paginator.dart` | Dot-style page indicator |
| `table.dart` | City data table |
| `package_manager.dart` | Spinner + progress multi-step |
| `spinner.dart` | Animated spinner |
| `spinners.dart` | Multiple spinner styles |
| `progress_bar.dart` | Interactive progress bar |
| `progress_animated.dart` | Auto-incrementing progress |
| `composable_views.dart` | Timer + spinner composition |
| `tabs.dart` | Tabbed interface |
| `views.dart` | Two-phase view transition |
| `pager.dart` | Scrollable pager with ViewportModel |
| `print_key.dart` | Key introspection |
| `cursor_style.dart` | Cursor shape / blink |
| `mouse.dart` | Mouse event logging |
| `realtime.dart` | Background async command |
| `send_msg.dart` | External `program.send()` |
| `timer.dart` | Countdown timer |
| `stopwatch.dart` | Elapsed-time stopwatch |
| `focus_blur.dart` | Focus/blur events |
| `prevent_quit.dart` | Filter to intercept QuitMsg |
| `sequence.dart` | batch() vs sequence() |
| `exec_cmd.dart` | External editor via execProcess() |
| `pipe.dart` | Piped stdin |
| `http.dart` | HTTP with spinner |
| `file_picker.dart` | FilePickerModel |
| `help.dart` | HelpModel + KeyMap |
| `color_profile.dart` | ColorProfileMsg and adaptive colors |
| `isbn_form.dart` | Validated TextInputModel |

Run any example with:

```bash
dart run example/simple.dart
```

## Benchmark command startup

Use the benchmark wrapper to consistently measure:

- `first_visible_ms`: time from process start to first printable output visible in terminal
- `total_runtime_ms`: time from process start to process exit

Run with multiple iterations (default 5 runs, 1 warmup):

```bash
python3 tool/bench_command.py -- fvm dart run example/showcase.dart
```

Control runs/warmups and write machine-readable output:

```bash
python3 tool/bench_command.py -n 10 --warmup 2 \
  --json-out .dart_tool/bench/showcase.json \
  -- fvm dart run example/showcase.dart
```

If you need to see child output live during benchmarking:

```bash
python3 tool/bench_command.py --passthrough -- fvm dart run example/showcase.dart
```

Optional shell helper:

```bash
dtbench() {
  python3 tool/bench_command.py -n "${1:-7}" --warmup 1 -- "${@:2}"
}
# Example:
dtbench 7 fvm dart run example/showcase.dart
```

For a full gallery with all examples and recordings, see [`example/README.md`](example/README.md).

### GIF previews

![simple](example/tapes/output/simple.gif)
![spinner](example/tapes/output/spinner.gif)
![table](example/tapes/output/table.gif)
![showcase](example/tapes/output/showcase.gif)

---

## License

MIT. Inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea) by [Charm](https://charm.sh). See [LICENSE](LICENSE).
