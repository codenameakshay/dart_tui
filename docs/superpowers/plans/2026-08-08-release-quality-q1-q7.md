# Release Quality Q1-Q7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Q1 through Q7 as seven sequential, verified release-quality commits.

**Architecture:** Characterize terminal behavior at the PTY boundary, then centralize shared renderer mode state before changing tooling and removing obsolete APIs. Each task leaves the branch working and owns a focused test gate plus one Lore-format commit.

**Tech Stack:** Dart 3, package:test, Python 3 standard-library PTY APIs, Make, GitHub Actions, npm/Next.js, Git.

---

### Task 1: Q1 PTY runtime characterization

**Files:**
- Create: `tool/pty_program_probe.dart`
- Create: `tool/pty_program_runtime_test.py`
- Modify: `.github/workflows/ci.yml`

- [ ] Write a Dart probe with `kill`, `cancel`, `resize`, and `suspend`
  scenarios. Each scenario runs a real `Program`, prints a unique visible
  marker from its model, and exits without private test hooks.
- [ ] Write Python PTY tests that bound every child with a timeout, use
  `TIOCSWINSZ` plus `SIGWINCH` for resize, observe `WUNTRACED` before sending
  `SIGCONT`, and assert cursor/alt-screen/paste teardown sequences.
- [ ] Run `python3 tool/pty_program_runtime_test.py` and confirm all four
  scenarios pass on Unix.
- [ ] Add the harness beside `pty_examples_smoke.py` in the non-Windows CI
  path and commit Q1 with PTY evidence in the Lore trailers.

### Task 2: Q2 shared terminal-mode state

**Files:**
- Create: `lib/src/terminal_mode_state.dart`
- Create: `test/terminal_mode_state_test.dart`
- Modify: `lib/src/renderer.dart`
- Modify: `test/renderer_test.dart`
- Modify: `test/cell_renderer_test.dart`

- [ ] Write failing helper tests for idempotent mode application, startup
  defaults, imperative alt-screen/cursor changes, mouse precedence, and reset.
- [ ] Run `dart test test/terminal_mode_state_test.dart` and confirm the helper
  is missing.
- [ ] Implement `TerminalModeState` with `apply`, `setAltScreen`,
  `setCursorVisibility`, `reset`, and an `altScreenEnabled` getter.
- [ ] Replace both renderer copies of the mode fields and transition methods
  with the helper, invalidating renderer-specific caches when the helper reports
  a screen change.
- [ ] Run the helper and both renderer suites, then commit Q2.

### Task 3: Q3 analyzer scope alignment

**Files:**
- Modify: `analysis_options.yaml`
- Modify: `Makefile`

- [ ] Run `make analyze` and record that it currently analyzes only `lib/`.
- [ ] Change the target to repository-wide `dart analyze` and exclude only
  `website/content/examples-src/**`, the verbatim slug-named website mirrors.
- [ ] Run `make analyze` and direct `dart analyze`; both must report no issues.
- [ ] Commit Q3 with the two commands in the Lore `Tested` trailer.

### Task 4: Q4 plain-Dart Make workflow

**Files:**
- Modify: `Makefile`
- Modify: `README.md`

- [ ] Run `make -n test` and confirm the default expands to `fvm dart test`.
- [ ] Set `DART ?= dart`, describe `DART='fvm dart'` as an optional override,
  and update help text and contributor prerequisites.
- [ ] Run `make -n test`, `make test`, and
  `make DART='dart' analyze`; all must use the plain SDK path and pass.
- [ ] Commit Q4.

### Task 5: Q5 tooling dependency refresh

**Files:**
- Modify: `pubspec.yaml`

- [ ] Run `dart pub outdated` and capture the current compatible/latest
  versions for `meta`, `lints`, and `test` under the installed Dart SDK.
- [ ] Update only those existing constraints to the chosen current compatible
  major versions; do not add packages.
- [ ] Run `dart pub get`, `dart analyze`, and `dart test`.
- [ ] Commit Q5 with resolved versions and verification in the Lore body.

### Task 6: Q6 published GIF payload reduction

**Files:**
- Modify: `README.md`
- Modify: `example/README.md`
- Modify: `.pubignore`

- [ ] Run `dart pub publish --dry-run` and record the current 61 GIF entries
  and archive size.
- [ ] Replace relative preview links with
  `https://dart-tui.vercel.app/gifs/<name>.gif` and exclude
  `example/tapes/output/` from pub packaging.
- [ ] Verify every referenced hosted GIF with an HTTP request and run a pub
  dry run that reports zero GIF entries and zero warnings.
- [ ] Commit Q6.

### Task 7: Q7 breaking compatibility cleanup

**Files:**
- Modify: `lib/src/model.dart`
- Modify: `lib/src/msg.dart`
- Modify: `lib/src/bubbles/style.dart`
- Modify: `lib/src/program.dart`
- Modify: `lib/src/forms/form.dart`
- Modify: `lib/src/gum.dart`
- Modify: `lib/src/prompts.dart`
- Modify: component models under `lib/src/bubbles/`
- Modify: affected files under `test/`, `example/`, `website/content/`,
  `README.md`, and `Makefile`

- [ ] Add/adjust compile-time tests for the canonical `Program(options: [...])`
  API and `withLogFile`, then run them against the old constructor to observe
  the expected failure.
- [ ] Delete `TeaModel` and migrate all inheritance and return types to
  `Model`; delete `LegacyKeyMsg` because it has no consumers.
- [ ] Delete `TuiStyle`, use immutable `Style` in examples, and use a private
  SGR reset constant inside style implementation/tests where raw protocol
  assertions are required.
- [ ] Delete `ProgramOptions` and `_compatOptions`; make
  `List<ProgramOption> options` the only constructor path, add `withLogFile`,
  and migrate forms, Gum helpers, prompts, tests, examples, website mirrors,
  and docs to option lists.
- [ ] Run `rg 'TeaModel|LegacyKeyMsg|TuiStyle|ProgramOptions|programOptions:'`
  over shipped Dart/docs surfaces and confirm no obsolete path remains.
- [ ] Run format, analysis, all tests, and `bash tool/compile_examples.sh`, then
  commit Q7 as an explicitly breaking change.

### Final release gate

- [ ] Run `dart format --output=none --set-exit-if-changed lib test example tool`.
- [ ] Run `dart analyze` and `bash tool/coverage.sh 90`.
- [ ] Run both PTY harnesses and `bash tool/compile_examples.sh`.
- [ ] Run `dart pub publish --dry-run` and confirm zero warnings/GIF payload.
- [ ] Run `npm audit --omit=dev`, `npm run lint`, and `npm run build` in
  `website/`.
- [ ] Review the seven-commit diff, push `codex/release-r1-r8`, update PR #14,
  and verify local/remote HEAD equality plus hosted checks.
