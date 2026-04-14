# Changelog

## 1.1.0

### New features

- **`ListModel`** (`bubbles/list.dart`): full-featured scrollable list with fuzzy/subsequence filtering, keyboard navigation (`↑↓ / jk`), filter mode (`/` to enter, `Esc` / `Backspace` to exit), viewport scrolling, optional descriptions, status bar (`x/y items`), and `FullListStyles` for per-element theming.
- **`TabsModel`** (`bubbles/tabs.dart`): tabbed-interface component with `(label, content)` pairs, `←/→ / h/l / Tab / Shift+Tab` navigation, and `TabsStyles` for active/inactive/divider/content theming.
- **SGR attributes** — three new text decorations on `Style`:
  - `isReverse` (SGR 7) — swap foreground and background
  - `isBlink` (SGR 5) — blinking text
  - `isOverline` (SGR 53) — overline decoration
- **`Style.inherit(parent)`** — fills every `null` field from a parent `Style`, enabling clean style composition without property repetition. All boolean SGR fields (`isBold`, `isDim`, `isItalic`, `isUnderline`, `isStrikethrough`, `isReverse`, `isBlink`, `isOverline`) changed from `bool` → `bool?` to support three-valued inheritance semantics.
- **`underlineSpaces`** / **`strikethroughSpaces`** — control whether underline / strikethrough decorations extend over padding spaces (default `true`, matching Lipgloss).
- **`borderForeground`** / **`borderBackground`** — independent `RgbColor` tinting for border characters, separate from text content color.
- **`borderTitle`** / **`borderTitleAlignment`** — embed a title string in the top border edge with `Align.left` / `.center` / `.right` positioning.
- **`wordWrap`** — `Style(wordWrap: true)` wraps at word boundaries before padding/border/constraint are applied; respects the `width` constraint.
- **`transform`** — `Style(transform: fn)` applies an arbitrary `String Function(String)` to the rendered content (useful for upper-casing, truncation, etc.).
- **`CompleteColor`** — per-profile color specification: `CompleteColor(trueColor: …, ansi256: …, ansi: …)`; used via `foregroundComplete` / `backgroundComplete` on `Style` for correct downgrade at each profile level.
- **`Border.hidden`** — a visible-but-blank border (spaces) that preserves box geometry without drawing any characters.
- **`EdgeInsets.symmetric({vertical, horizontal})`** and **`EdgeInsets.only({top, right, bottom, left})`** — additional named constructors matching Flutter conventions.
- **Layout helpers** now accept enums instead of raw `double` fractions:
  - `joinHorizontal(AlignVertical, List<String>)` — was `double`
  - `joinVertical(Align, List<String>)` — was `double`
  - `place(width, height, Align, AlignVertical, content)` — was two `double` args
  - `placeHorizontal(width, Align, content)` — new helper
  - `placeVertical(height, AlignVertical, content)` — new helper
- **Terminal control Cmd helpers** (`cmd.dart`):
  - `enterAltScreen()` / `exitAltScreen()` — emit `EnterAltScreenMsg` / `ExitAltScreenMsg`
  - `hideCursor()` / `showCursor()` — emit `HideCursorMsg` / `ShowCursorMsg`
  - `setWindowTitle(title)` — `Cmd` that emits `SetWindowTitleMsg`
  - `clearScrollArea()` — emits `ClearScrollAreaMsg`
  - `scrollUp([n = 1])` / `scrollDown([n = 1])` — `Cmd` that emits `ScrollMsg`
- **Renderer interface** extended: `setAltScreen(bool)`, `setCursorVisibility(bool)`, `scroll(int, {bool up})` added to `TeaRenderer` and implemented by `AnsiRenderer`, `CellRenderer`, and `NilRenderer`.
- **`stripAnsi(String)`** — public utility that strips all ANSI escape sequences from a string; previously internal-only.

### New examples

| Example | What it shows |
|---------|---------------|
| `word_wrap.dart` | `Style.wordWrap` at multiple widths with box, rounded, and thick borders + border title |
| `border_style.dart` | All 6 `Border` variants, `borderForeground` / `borderBackground`, and all three `borderTitle` alignments |
| `sgr_attrs.dart` | All 8 SGR text attributes; `Style.inherit()` composition |
| `list_filter.dart` | `ListModel` with fuzzy filtering, descriptions, status bar, and selection |

`tabs.dart` updated to use the exported `TabsModel` bubble instead of an inline reimplementation.

### Tests

9 new test files, 90+ new test cases:
`style_sgr_test.dart`, `style_border_test.dart`, `style_wordwrap_test.dart`, `canvas_test.dart`, `gradient_test.dart`, `adaptive_color_test.dart`, `cmd_terminal_test.dart`, `list_model_test.dart`, `tabs_model_test.dart`.

### Breaking changes

- `joinHorizontal`, `joinVertical`, and `place` now accept enum arguments (`AlignVertical`, `Align`) instead of raw `double` fractions. Migrate: `0.0 → AlignVertical.top`, `0.5 → AlignVertical.middle`, `1.0 → AlignVertical.bottom`; `0.0 → Align.left`, `0.5 → Align.center`, `1.0 → Align.right`.
- All boolean SGR fields on `Style` (`isBold`, `isDim`, `isItalic`, `isUnderline`, `isStrikethrough`) changed from `bool` (default `false`) to `bool?` (default `null`). Existing code that reads these fields may need a null-aware comparison (`style.isBold == true` or `style.isBold ?? false`).

---

## 1.0.0+1

### Bug fixes

- **Terminal hang on exit**: awaiting the stdin subscription cancel in the shutdown path so the Dart event loop is fully released before the process exits. Previously the `unawaited` cancel could leave stdin holding the event loop open, requiring a manual Ctrl-C to regain the shell prompt.
- **Terminal not restored on quit**: flushing ANSI reset sequences (show cursor, exit alt-screen) before the process exits so the shell prompt appears on a clean line.

### Other changes

- **Enter / LF key fix**: `0x0a` (LF / `\n`) now correctly maps to `KeyCode.enter`, fixing silent key drops on Linux/WSL terminals that send LF instead of CR for Enter.
- **Batch render loop**: all pending messages are drained before each render; a single render fires per batch, eliminating up to 16 ms of FPS-throttle lag per key press.
- **Deferred capability queries**: `CSI ?2026$y` and `OSC 11` are sent after the first rendered frame so startup is not delayed.
- **Makefile**: `make format` (dart format check), `make test`, `make analyze`, `make run/run-fast/kernels/bench/gifs/new-example`.
- **Analyzer clean**: resolved all `strict_raw_type`, `unused_local_variable`, `prefer_const_constructors`, `library_private_types_in_public_api`, and `avoid_relative_lib_imports` warnings.

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
