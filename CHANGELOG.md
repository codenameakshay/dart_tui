# Changelog

## Unreleased

### Added

- **Scrollback preservation outside the alternate screen (#18):** when
  running without `withAltScreen()`, the program now scrolls the visible
  screen into the scrollback buffer before painting its first frame instead
  of overwriting the shell session, and on exit leaves the cursor just below
  the final view so the prompt reappears cleanly. Opt out with
  `withoutInitialScroll()`.

### Fixed

- `TerminalModeState.reset()` no longer emits an alt-screen exit (`CSI
  ?1049l`) when the alternate screen was never enabled.
- `clearScrollArea()` no longer clears the screen twice.

## 2.0.0 - 2026-08-08

This major release hardens the terminal runtime, ports the selected Bubble Tea
capabilities through P9, and removes the temporary compatibility APIs so the
package has one clear model, styling, and program-configuration path.

### Breaking changes

- **Models:** removed the `TeaModel` alias. Extend or implement `Model`
  directly.
- **Keys:** removed the `LegacyKeyMsg` alias. Use `KeyPressMsg` for press
  events or the shared `KeyMsg` base type.
- **Styles:** removed the raw ANSI `TuiStyle` helpers. Use immutable `Style`
  values such as `const Style(isBold: true).render(text)`.
- **Program configuration:** removed `ProgramOptions` and the parallel
  `programOptions` / `programSettings` parameters. `Program`, forms, prompts,
  and gum helpers now accept one `List<ProgramOption>` named `options`. Use
  `withAltScreen()`, `withTickInterval(...)`, `withHideCursor(...)`, and
  `withLogFile(File(...))` for the former struct fields.

### Bubble Tea parity

- Added declarative terminal colors, native progress reporting, keyboard
  options, and view-level mouse callbacks.
- Added Kitty progressive-keyboard negotiation and modern key press, repeat,
  and release events.
- Added Unicode Core negotiation plus shared grapheme-aware terminal width
  handling across input, styling, and rendering.
- Expanded the viewport with gutters, per-line styles, search highlights,
  filling, and horizontal navigation.
- Added dynamically sized, visually wrapped textarea behavior.
- Added multi-stop, scaled, and callback-driven progress colors.
- Added rich underline styles, OSC 8 hyperlinks, and ANSI-state-safe layout
  operations.
- Added explicit dark/light component style factories and immutable
  suggestion, cursor, and viewport introspection APIs.

### Runtime correctness and security

- Made cell diffs width-aware for CJK, emoji, and other double-width
  graphemes, while reducing cell parsing from quadratic to linear work.
- Made declarative cursor position, shape, blink, and color reach the terminal.
- Correctly consume OSC, DCS, APC, PM, and SOS control strings without leaking
  payload bytes into rendered cells.
- Made `Program.kill()` wake idle programs and restore terminal state.
- Corrected Unicode capability-report semantics and sanitized window-title OSC
  payloads.
- Preserved cumulative SGR and OSC 8 hyperlink state in `CellRenderer`, made
  multi-grapheme input edits atomic, and restored viewport line styles around
  highlighted spans.

### Release quality and tooling

- Added real-PTY tests for kill, external cancellation, resize,
  suspend/resume, and terminal restoration.
- Centralized alternate-screen, cursor, focus, paste, and mouse transitions in
  one terminal-mode state machine shared by both renderers.
- Aligned local and CI analysis on one clean repository-wide boundary.
- Made plain Dart the default across Make targets, examples, VHS tapes, and
  website source mirrors; FVM remains an optional override.
- Refreshed `meta`, `lints`, and `test` constraints to their current resolvable
  releases.
- Moved README previews to the hosted documentation assets and excluded local
  GIF binaries from the pub archive.

### Documentation and examples

- Upgraded the documentation site to patched Next.js 16.3.0 with dedicated
  audit, typecheck, and production-build CI.
- Refreshed the component gallery, guides, API snippets, and all 60
  tape-backed example previews for the 2.0 API.

## 1.4.0

### Forms (huh-style)

A composable, immutable, key-based forms subsystem — the equivalent of Charm's [huh](https://github.com/charmbracelet/huh).

- **`Form`** (`forms/form.dart`) — an immutable `TeaModel` you can embed (exposes `submitted`/`cancelled`/`values`), or run one-shot with `await form.run()` (returns `FormValues?`, `null` if cancelled). Groups of fields render one page at a time as a wizard, with a `Group N/M` indicator.
- **Field types** via the `Field` factory: `input`, `password`, `text` (multiline), `file`, `select` / `selectOf<T>`, `multiSelect` / `multiSelectOf<T>`, `confirm`, `note`. Text-ish fields reuse `TextInputModel`/`TextAreaModel`/`FilePickerModel`.
- **Key-based values** — `FormValues.get<T>(key)`; hidden fields are excluded from the result.
- **Validation** — per-field `validate` with inline errors; blocks advancing and submit.
- **Dynamic / conditional fields** — any field or group takes `hidden: (FormValues) => bool`; titles and select options can be computed from other fields' values (`titleFor`, `optionsFor`), recomputed on every change with selection clamping.
- **Navigation** — `Tab`/`Enter` advance (Enter inserts a newline in multiline `text`; `Tab`/`Ctrl+D` advance there), `Shift+Tab` back, `Esc`/`Ctrl+C` cancel.
- **`FormStyles`** — Catppuccin Mocha defaults.
- New `form.dart` example + VHS tape.

### Fixes

- **`TextInputModel` / `TextAreaModel`**: typing a space inserted the literal string `"space"` (and F-keys inserted `"f1"`, etc.) because the default branch inserted the keystroke name rather than the character. Now only unmodified printable runes are inserted, using the actual rune text — so text fields (and form inputs) accept spaces correctly.

### Docs

- New [documentation website](https://dart-tui.vercel.app) — a searchable gallery of every component, block and guide with live GIF previews and copyable source. Lives in `website/` (excluded from the published package via `.pubignore`).

## 1.3.0

### New components & helpers

- **`Spring`** (`bubbles/spring.dart`) — harmonica-style damped-harmonic-oscillator for smooth eased motion of any scalar (progress, scroll, cursor). Pure math, no terminal I/O: `Spring(fps:, frequency:, damping:).update(pos, vel, target)` plus `fpsToDelta()`.
- **`FileLog`** (`log.dart`) — append timestamped diagnostics to a file. Because a running `Program` owns stdout, `print()` corrupts the UI; write here and `tail -f` instead. `FileLog.none()` discards.
- **gum-style one-shot helpers** (`gum.dart`) — `filter()` (interactive fuzzy picker), `spin()` (run a spinner while awaiting a `Future`, returns its result), and `pager()` (scrollable viewer). Each takes a `programOptions` list for headless testing.
- **`ListModel` runtime mutation API** — `withItems`, `appendItem`, `insertItem`, `removeItemAt`, `setItemAt`, `select`, and `selectedIndex`; all clamp the cursor.
- **Readline / emacs editing keys** for `TextInputModel` and `TextAreaModel` — `ctrl+a`/`ctrl+e` (home/end), `ctrl+b`/`ctrl+f` (char left/right), `alt+←`/`alt+→` (word motion), and `ctrl+w` / `alt+backspace` (delete previous word).

### Examples

Five new runnable examples (each with a VHS tape): `spring`, `gum` (filter/spin/pager), `list_mutation`, `readline`, and `file_log`.

### Performance

Hot-path allocation and CPU reductions on the per-frame render and per-keystroke paths (all behaviour-preserving, covered by regression tests):

- `stripAnsi` fast-path (skip the regex when there is no escape) plus a single-grapheme width helper — the width/wrap/truncate/pad path no longer runs a regex per grapheme.
- `ViewportModel` reuses its wrapped lines across scrolling instead of re-wrapping every frame.
- `AnsiRenderer` and `CellRenderer` skip the grid rebuild / diff walk on identical frames; the redundant per-frame list copy is gone.
- `ListModel.filteredItems` is memoised; `TreeModel` reuses its flattened node list on cursor-only changes.
- The render throttle uses a precomputed frame budget and a monotonic `Stopwatch`.

### Fixes

- **Prompts no longer hang on cancel.** `promptSelect` / `promptConfirm` / `promptInput` set `finished` on Esc/Ctrl+C but never quit, and raw mode delivers Ctrl+C as a byte (not SIGINT) — so cancelling hung forever. They now quit cleanly and return `null`. The three prompt helpers also gained a `programOptions` parameter for headless/scripted use.

### Quality

- Test suite grown from 423 to 560+ cases; measured `lib/` line coverage raised from ~67% to **92%**.
- New `make coverage [FLOOR=90]` target and a CI coverage gate (Linux/macOS) that fails below the floor, honouring `// coverage:ignore-*` markers for genuinely-untestable code (Win32 FFI, raw-mode TTY, OS signals).

## 1.2.0

### New components

- **`CursorModel`** (`bubbles/cursor.dart`): in-line blinking cursor widget with three display modes — `CursorMode.block` (`█`), `CursorMode.underline` (`_`), and `CursorMode.bar` (`|`). Toggles visibility on every `TickMsg` when `blink: true`. Useful for building custom text editors, prompts, or any UI that needs a visible insertion point independent of the real terminal cursor. Supports `focus()`/`blur()` to pause blinking, and `withMode()`/`withBlink()` builders.

- **`MultiSelectModel`** (`bubbles/multi_select.dart`): scrollable checkbox list supporting multiple concurrent selections. Navigate with `↑↓ / jk`, toggle with `Space` or `x`, select/deselect all with `a`, confirm with `Enter`. Features:
  - `wrap: bool` — cursor wraps at list boundaries
  - `height` — viewport limiting
  - `showStatusBar` — `"N/Total selected"` footer
  - `selectedValues` getter — returns custom `value` or falls back to `label`
  - `MultiSelectStyles` for full per-element theming (Catppuccin Mocha defaults)

### New `ProgramOption` functions

Seven new fluent option functions complement the existing `ProgramOptions` struct:

```dart
withAltScreen()                                    // enter alt-screen buffer at startup
withHideCursor([bool hide = true])                 // hide/show terminal cursor at startup
withTickInterval(Duration interval)                // emit TickMsg at a fixed interval
withMouseCellMotion()                              // enable button-event mouse tracking
withMouseAllMotion()                               // enable all-motion mouse tracking
withReportFocus()                                  // emit FocusMsg / BlurMsg on window focus
withWindowSize(int width, int height)              // inject fixed dimensions (useful in tests)
```

These compose with `ProgramOptions` and take precedence over it; `defaultMouseMode` and `defaultReportFocus` act as floor values so per-`View` overrides still work.

### Style additions

- **`Border.normal`** — ASCII-art border (`+`, `-`, `|`) for environments without Unicode box-drawing support.
- **Per-side border flags** — `Border` now has `showTop`, `showRight`, `showBottom`, `showLeft` (all default `true`). Use `Style.withBorderSides({top, right, bottom, left})` or the pre-built helpers `Border.topOnly`, `Border.bottomOnly`, `Border.sidesOnly` to draw partial borders.
- **`Border.copyWith()`** — produce modified `Border` instances without recreating all fields.
- **`tabWidth: int`** field on `Style` (default `4`) — `\t` characters are expanded to spaces before rendering. Use `Style.withTabWidth(n)` fluent builder.
- **`marginBackground: RgbColor?`** field on `Style` — fills the margin area with a solid ANSI background colour. Use `Style.withMarginBackground(color)` fluent builder.
- **`getWidth(String)`** (public) — visible terminal column width after stripping ANSI and counting double-wide characters.
- **`getHeight(String)`** (public) — number of newline-delimited lines.
- **`truncate(String, int)`** (public) — drop trailing visible columns to fit `maxWidth`; ANSI-safe.
- **`truncateLeft(String, int)`** (public) — drop leading visible columns; ANSI codes in the kept portion are preserved.

### Component navigation & mouse improvements

- **`ListModel`** — added `pgup` / `ctrl+b`, `pgdown` / `ctrl+f`, `home` / `g`, `end` / `G` key bindings; `viewOffsetY` field for click-to-select mouse handling; mouse wheel scrolling.
- **`SelectListModel`** — added `wrap: bool` (cursor wraps at list boundaries).
- **`TableModel`** — added `viewOffsetY` and mouse handling (wheel up/down, left-click to select with header offset).
- **`TreeModel`** — added `viewOffsetY` and mouse handling (wheel scroll, left-click to move cursor); fixed `' '` space key mapping to `'space'` keystroke.

### New examples

| Example | What it shows |
|---------|---------------|
| `cursor_model.dart` | `CursorModel` — all three blink modes side-by-side, toggle blink with `b` |
| `multi_select.dart` | `MultiSelectModel` — toggle, select-all, confirm, display result |

### Tests

10 new test files, 160+ new test cases:

| File | Coverage |
|------|----------|
| `spinner_test.dart` | SpinnerModel state transitions |
| `select_list_test.dart` | SelectListModel navigation, wrap, view |
| `progress_test.dart` | ProgressModel rendering and clamping |
| `help_test.dart` | HelpModel expand/collapse, KeyMap |
| `paginator_test.dart` | PaginatorModel navigation, bounds, view |
| `cursor_model_test.dart` | CursorModel blink, focus, modes, view |
| `multi_select_test.dart` | MultiSelectModel toggle, select-all, wrap, view |
| `program_options_test.dart` | Integration: each ProgramOption emits correct ANSI sequences |
| `input_decoder_test.dart` | TerminalInputDecoder — 48 edge-case / fuzz-style tests |
| `style_properties_test.dart` | Property-based invariants for getWidth, getHeight, truncate, Style.render, joinH/V, stripAnsi |

### Other

- All 54 VHS GIFs regenerated from current kernel snapshots.

---

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
