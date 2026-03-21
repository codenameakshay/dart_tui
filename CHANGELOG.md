# Changelog

## Unreleased

- Runtime: moved to message-driven rendering with frame diffing.
- Runtime: terminal request commands now send real CSI/OSC/DCS queries.
- Input decoding: added CSI/OSC/DCS parsing for cursor position, colors, clipboard, mouse SGR, and capability replies.
- Breaking: removed legacy alias APIs (`Batch`, `Quit`, `Println`, `WithInput`, etc.) in favor of canonical lowercase APIs.
- Testing: added PTY example smoke harness (`tool/pty_examples_smoke.py`) and CI matrix for Linux + macOS.

## 0.1.0

- Initial release: `Program` runtime (Elm-style `Model`, `Msg`, `Cmd`, `Batch`).
- Terminal integration via `dart_console` (raw keys, window size, resize).
- Components: `ListModel`, `TextInputModel`, `SpinnerModel`, `ProgressModel`.
- Optional `prompts` helpers: `select`, `confirm`, `input`.
- Example: shopping list (Bubble Tea tutorial port).
