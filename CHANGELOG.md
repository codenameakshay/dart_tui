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

### Performance improvements

- **Enter / LF key fix**: `0x0a` (LF / `\n`) was silently decoded as `ctrl+j` and dropped by all components. It is now correctly mapped to `KeyCode.enter`, matching Linux/WSL terminal behaviour.
- **Batch render loop**: messages are now drained without re-rendering between each one; a single render fires per batch. Eliminates up to 16 ms of FPS-throttle lag per key press.
- **Unawaited commands**: `runCmd` is now fire-and-forget so command results arrive as the next queued message without blocking key event processing.
- **Deferred capability queries**: `CSI ?2026$y` (synchronized-updates query) and `OSC 11` (background-color query) are sent after the first rendered frame, so the initial visible output is not delayed.
- **Kernel snapshot build**: `tool/build.sh --kernel` compiles examples to `.dill` kernel snapshots (~550 ms startup vs ~1 050 ms JIT source on WSL2).
- **Makefile**: added targets for `test`, `analyze`, `run`, `run-fast`, `kernels`, `bench`, `gifs`, `new-example`, and more.
- **48 GIFs re-recorded** from kernel snapshots for faster, cleaner recordings.

### Bug fixes

- **Terminal not restored on quit**: added `_output.writeln()` + `await _output.flush()` in the `finally` block so ANSI reset sequences (show cursor, exit alt-screen) are flushed to the terminal before the shell regains control.
- **Terminal hang on exit**: awaiting the stdin subscription cancel in the shutdown path so the Dart event loop is fully released before the process exits. Previously the `unawaited` cancel could leave stdin holding the event loop open, requiring a manual Ctrl-C to regain the shell prompt.

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
