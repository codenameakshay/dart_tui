# Changelog

## 1.0.0

### New features

- **CellRenderer**: cell-level diff renderer using grapheme clusters (`characters` package) — only changed cells emit ANSI sequences, eliminating flicker.
- **Synchronized updates**: CSI `?2026h/l` wrapping for flicker-free frames on terminals that support it.
- **ExecMsg / execProcess()**: run external processes (e.g. `$EDITOR`) with full terminal hand-off and optional exit-code callback.
- **TextAreaModel**: multi-line editor with `charLimit`, ctrl+k/ctrl+u line-kill, cursor navigation.
- **ViewportModel**: scrollable content pane with soft-wrap, `atBottom`/`scrollPercent`, keyboard navigation.
- **TableModel** + **TableColumn**: tabular data viewer with header, separator, scrolling cursor, and optional row styles.
- **TimerModel**: countdown timer, `start()`/`stop()`/`reset()` builders, `TickMsg` routing by `id`.
- **StopwatchModel**: elapsed-time stopwatch with millisecond display.
- **KeyMap** + **KeyBinding** + **HelpModel**: declarative keybinding registry; help UI with compact/full toggle.
- **FilePickerModel**: async directory browser with extension filtering.
- **Style system**: Lipgloss-inspired `Style` with `width`/`height` constraints, `Align`/`AlignVertical`, `inline` mode, `AdaptiveColor`, `Border` variants; `joinHorizontal()`, `joinVertical()`, `place()` layout helpers.
- **EchoMode** (normal / password / none) and `suggestions` (tab-completion) on `TextInputModel`.
- **ValidationFailedMsg** + validate callback on `TextInputModel`.
- **`tickWithId(Duration, Object)`**: tick Cmd with routing ID for composable timers.
- **`batch()` / `sequence()`**: concurrent vs. ordered command scheduling.
- **Mouse support**: `MouseMode.cellMotion` / `allMotion`; `MouseClickMsg`, `MouseMotionMsg`, `MouseWheelMsg`.
- **Cursor control**: `View.cursor` with `CursorShape` (block / underline / bar) and blink flag.
- **Focus reporting**: `View.reportFocus`, `FocusMsg`, `BlurMsg`.
- **Window title**: `View.windowTitle` OSC sequence.
- **41 examples**: complete port of the Bubbletea example gallery.

### Breaking changes from 0.1.0

- Legacy Go-style uppercase API aliases removed (`Batch`, `Sequence`, `Quit`, `Println`, `WithInput`, etc.) — use canonical lowercase equivalents.
- `request*` commands now emit real terminal protocol queries; decoder responses feed back as typed `Msg` values.
- `ListModel` renamed to `SelectListModel`.

## 0.1.0

- Initial release: `Program` runtime (Elm-style `Model`, `Msg`, `Cmd`, `Batch`).
- Terminal integration via `dart_console` (raw keys, window size, resize).
- Components: `ListModel`, `TextInputModel`, `SpinnerModel`, `ProgressModel`.
- Optional `prompts` helpers: `select`, `confirm`, `input`.
- Example: shopping list (Bubble Tea tutorial port).
