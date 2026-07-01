# Cheap Tier-B Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (TDD, commit per feature). Plan 3 of 4 for release 1.3.0, executed inline on `release/1.3.0-perf`.

**Goal:** Add five small, high-DX, low-risk additions verified as worthwhile: a spring-animation utility, a runtime list-mutation API, a file-logging helper, readline-style editing keys for the text widgets, and gum-style one-shot helpers.

**Architecture:** Mostly additive. New leaf utilities (`spring.dart`, `log.dart`), new methods on existing immutable models (list, text_input, text_area), and new one-shot `Program`-based helpers (`gum.dart`) alongside the existing `prompts.dart`. Each feature is TDD'd and committed independently; every addition is exported from the barrel.

**Tech Stack:** Dart, `package:test`.

---

## Feature 1: Harmonica spring animation (`lib/src/bubbles/spring.dart`)

A pure damped-harmonic-oscillator, framework-agnostic (no terminal I/O), for smooth eased motion of any scalar.

- `fpsToDelta(int fps) → double` — seconds-per-frame.
- `class Spring { Spring({required double fps, required double frequency, required double damping}); (double pos, double vel) update(double pos, double vel, double target); }`
- Standard critically/under/over-damped behaviour; converges to `target` with `vel→0`.
- Test: from (0,0)→target 100 over N frames approaches 100; velocity decays; over-damped never overshoots.

## Feature 2: List runtime mutation API (`lib/src/bubbles/list.dart`)

Thin, immutable helpers so callers can mutate items without rebuilding the whole model:
- `withItems(List<ListItem>)`, `appendItem(ListItem)`, `insertItem(int, ListItem)`, `removeItemAt(int)`, `setItemAt(int, ListItem)`, `select(int)` (clamps), `selectedIndex → int`.
- All clamp the cursor and preserve title/height/styles/filter.
- Test: append grows list; removeItemAt shrinks + clamps cursor; select clamps; selectedIndex reflects cursor.

## Feature 3: File-logging helper (`lib/src/log.dart`)

Because the renderer owns stdout, `print()` corrupts the UI. Provide an opt-in file logger:
- `class FileLog { FileLog(String path); void call(Object? msg); void close(); }` — appends timestamped lines. (Timestamp injected/overridable so tests are deterministic.)
- `FileLog.debug(...)` no-op sink when path is null.
- Test: writes lines to a temp file; multiple calls append; close flushes.

## Feature 4: Readline editing keys (`text_input.dart`, `text_area.dart`)

Add the common emacs/readline bindings people expect:
- `ctrl+a` → home, `ctrl+e` → end, `ctrl+b`/`ctrl+f` → left/right (text_input), `ctrl+w` / `alt+backspace` → delete word before cursor, `alt+b`/`alt+f` → word-left/right.
- Word boundary = run of non-space then trailing spaces.
- Test: `ctrl+w` deletes the previous word; `ctrl+a`/`ctrl+e` jump; word motions land on boundaries.

## Feature 5: gum-style one-shot helpers (`lib/src/gum.dart`)

Sugar built on `Program` + `OutcomeModel`, mirroring `prompts.dart` (with the same `programOptions` seam for headless testing):
- `Future<String?> filter(List<String> options, {...})` — interactive fuzzy filter (built on `ListModel`), returns the chosen string or null.
- `Future<T> spin<T>(Future<T> task, {String label})` — render a spinner while awaiting `task`, return its result.
- `Future<void> pager(String content, {...})` — scrollable viewer (built on `ViewportModel`) until `q`/Esc.
- NOT `join` — `joinHorizontal`/`joinVertical` already exist.
- Test: drive `filter` headlessly (type query + enter → selection; esc → null); `spin` returns the task result.

## Barrel + Verification

- Export `spring.dart`, `log.dart`, `gum.dart` from the package.
- `dart analyze` clean, `dart format` clean, `dart test` all pass, `make coverage` stays ≥ 90%.

## Self-Review
Each feature is independently useful and testable; readline keys and list mutation extend existing models without breaking APIs; gum/log/spring are new opt-in surfaces. `join` correctly excluded (already present).
