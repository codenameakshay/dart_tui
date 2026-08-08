# Bubble Tea P1–P9 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the selected Bubble Tea/Bubbles/Lip Gloss P1–P9 capabilities to `dart_tui`, each as a verified standalone commit.

**Architecture:** Extend the existing immutable models and renderers. Put terminal serialization/parsing and grapheme width in focused internal helpers, while component APIs remain public through existing barrel exports.

**Tech Stack:** Dart 3.5+, `characters`, existing `dart_tui` ANSI/style utilities, `package:test`, PTY smoke scripts, Next.js documentation site.

---

### Task 1: P1 declarative terminal state

**Files:**
- Create: `lib/src/terminal_view_state.dart`
- Modify: `lib/src/view.dart`
- Modify: `lib/src/renderer.dart`
- Modify: `lib/src/program.dart`
- Test: `test/renderer_test.dart`
- Test: `test/cell_renderer_test.dart`
- Test: `test/program_control_test.dart`

- [ ] Add failing tests proving both renderers emit OSC 10/11 colors, OSC 9;4 progress, reset removed fields, and do not repeat unchanged state.
- [ ] Add a failing program test where `View.onMouse` produces a message that reaches `update` through the normal command queue.
- [ ] Run `dart test test/renderer_test.dart test/cell_renderer_test.dart test/program_control_test.dart` and confirm failures show absent view-state sequences and callback dispatch.
- [ ] Implement one `_TerminalViewState` transition writer used by both renderers. Clamp progress to 0–100 and serialize RGB as `#rrggbb`.
- [ ] Retain the last rendered `onMouse` callback on the renderer and have `Program` schedule its command for concrete mouse events.
- [ ] Run the focused tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Make declarative terminal state authoritative` and Lore trailers recording tests and terminal-protocol constraints.

### Task 2: P2 Kitty progressive keyboard protocol

**Files:**
- Create: `lib/src/kitty_keyboard.dart`
- Modify: `lib/src/view.dart`
- Modify: `lib/src/msg.dart`
- Modify: `lib/src/input_decoder.dart`
- Modify: `lib/src/renderer.dart`
- Test: `test/input_decoder_test.dart`
- Test: `test/renderer_test.dart`
- Test: `test/cell_renderer_test.dart`

- [ ] Add decoder tests for `CSI ? flags u`, CSI-u press/repeat/release, shifted/base code subparameters, associated text, split input, and malformed complete sequences.
- [ ] Add renderer tests expecting basic flag 1 by default, requested flags 2/4/8/16, a capability query, and reset on release.
- [ ] Run the focused tests and confirm failures are caused by unsupported CSI-u behavior.
- [ ] Define Kitty flag constants and make `TeaKey.shiftedCode`/`baseCode` Unicode code points plus an `associatedText` value.
- [ ] Parse CSI-u parameters into modifiers and `KeyPressMsg`/`KeyReleaseMsg`; expose all capability predicates.
- [ ] Serialize declarative flags through the P1 state helper and restore the terminal keyboard level during release.
- [ ] Run focused tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Preserve modern keyboard events end to end` and Lore trailers.

### Task 3: P3 Unicode mode 2027 and grapheme width

**Files:**
- Create: `lib/src/grapheme_width.dart`
- Modify: `lib/src/program.dart`
- Modify: `lib/src/renderer.dart`
- Modify: `lib/src/bubbles/style.dart`
- Modify: `lib/src/bubbles/text_input.dart`
- Test: `test/program_control_test.dart`
- Test: `test/cell_renderer_test.dart`
- Test: `test/grapheme_width_test.dart`

- [ ] Add failing tests for mode-2027 startup query, supported enable, unsupported no-op, release reset, and restore re-enable.
- [ ] Add width tests for combining marks, CJK, variation-selector emoji, flags, skin tones, and ZWJ families.
- [ ] Run focused tests and confirm protocol/width assertions fail for the missing feature.
- [ ] Implement `graphemeWidth(String)` and replace duplicated width heuristics in renderers/style/text input.
- [ ] Handle `ModeReportMsg(mode: 2027)` in `Program`; emit query/set/reset only at lifecycle boundaries.
- [ ] Run focused tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Keep terminal and application Unicode width in agreement` and Lore trailers.

### Task 4: P4 viewport v2 bundle

**Files:**
- Modify: `lib/src/bubbles/viewport.dart`
- Test: `test/viewport_test.dart`

- [ ] Add failing tests for gutters, logical/soft line context, line styles, fill height, literal search, next/previous wraparound, visibility, clearing, and horizontal wheel buttons.
- [ ] Run `dart test test/viewport_test.dart` and confirm missing APIs/behavior fail.
- [ ] Add immutable `ViewportGutterContext`, `ViewportHighlight`, builder/style callbacks, search state, and copy methods.
- [ ] Render gutter outside the horizontally scrolled content, apply highlights before line style, and pad when fill height is enabled.
- [ ] Make highlight navigation clamp both offsets and make wheel-left/right call horizontal scrolling.
- [ ] Run viewport tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Make the viewport useful for navigable source content` and Lore trailers.

### Task 5: P5 dynamic-height textarea

**Files:**
- Modify: `lib/src/bubbles/text_area.dart`
- Test: `test/text_area_test.dart`

- [ ] Add failing tests for newline and soft-wrap growth, deletion shrinkage, min/max visible height, max visual content rejection, PageUp/PageDown, cursor visibility, and scroll clamping.
- [ ] Run `dart test test/text_area_test.dart` and confirm missing dynamic-height behavior fails.
- [ ] Add `dynamicHeight`, `minHeight`, and `maxContentHeight` fields while making `maxHeight` exclusively the visible ceiling.
- [ ] Build visual rows from grapheme-safe wrapping, translate logical cursor position to a visual row, and derive effective height/scroll from that representation.
- [ ] Reject insertions atomically when visual content would exceed the limit; implement page navigation against visual rows.
- [ ] Run textarea tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Let textareas grow without surrendering scroll control` and Lore trailers.

### Task 6: P6 rich progress colors

**Files:**
- Modify: `lib/src/bubbles/progress.dart`
- Test: `test/progress_test.dart`

- [ ] Add failing tests for three-stop interpolation, scaled and unscaled gradients, callback precedence, one-color fallback, and 0%/100% boundaries.
- [ ] Run `dart test test/progress_test.dart` and confirm missing color APIs fail.
- [ ] Add `ProgressColorBuilder`, immutable `colors`, and `scaleGradient` configuration.
- [ ] Resolve each filled cell color in callback/blend/solid precedence and use the existing `blend` utility for adjacent stops.
- [ ] Run progress tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Let progress color communicate changing state` and Lore trailers.

### Task 7: P7 hyperlinks and rich underlines

**Files:**
- Create: `lib/src/ansi_state.dart`
- Modify: `lib/src/bubbles/style.dart`
- Test: `test/style_sgr_test.dart`
- Test: `test/style_test.dart`

- [ ] Add failing tests for all underline substyles, RGB underline color/reset, balanced OSC 8 output, payload sanitization, and link/style preservation through wrap and truncate.
- [ ] Run the focused style tests and confirm failures describe missing SGR/OSC state.
- [ ] Add `UnderlineStyle`, underline color, hyperlink URL/params, immutable fluent methods, render encoding, and reset encoding.
- [ ] Implement a streaming ANSI/OSC state tracker that closes and reopens active state at inserted line boundaries and closes state at truncation.
- [ ] Sanitize hyperlink metadata before serialization; never accept BEL, ESC, ST, C0, DEL, or C1 bytes.
- [ ] Run style tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Keep rich terminal text safe across layout boundaries` and Lore trailers.

### Task 8: P8 light/dark component defaults

**Files:**
- Modify: `lib/src/bubbles/help.dart`
- Modify: `lib/src/bubbles/list.dart`
- Modify: `lib/src/bubbles/text_input.dart`
- Modify: `lib/src/bubbles/text_area.dart`
- Modify: `lib/src/forms/form_styles.dart`
- Test: `test/adaptive_component_styles_test.dart`

- [ ] Add failing tests that each style family produces legible contrasting light/dark colors and that `forBackground` matches the existing luminance detector.
- [ ] Run `dart test test/adaptive_component_styles_test.dart` and confirm missing factories fail.
- [ ] Add `forDarkBackground(bool)` and `forBackground(int)` factories to all five style families, using explicit light and dark palettes.
- [ ] Keep each component's default equal to its dark-background factory without global mutable theme state.
- [ ] Run adaptive style tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Make component defaults respect terminal brightness` and Lore trailers.

### Task 9: P9 input introspection

**Files:**
- Modify: `lib/src/bubbles/text_input.dart`
- Modify: `lib/src/bubbles/text_area.dart`
- Test: `test/text_input_test.dart`
- Test: `test/text_area_test.dart`

- [ ] Add failing tests for ordered matched suggestions, selected suggestion/index, grapheme cursor columns, scroll/height getters, and immutable line/document boundary movement.
- [ ] Run focused input tests and confirm missing public APIs fail.
- [ ] Expose cached matched suggestions and selection state on `TextInputModel`; make Tab use that same state.
- [ ] Add explicit immutable movement methods and grapheme-index introspection to both input models.
- [ ] Run focused tests, `dart analyze`, and `dart test`; require all to pass.
- [ ] Commit with intent `Expose input state without leaking rendering internals` and Lore trailers.

### Task 10: Release-wide verification and push

**Files:**
- Modify only if a verification failure exposes a P1–P9 defect; amend the responsible port commit rather than create an unrelated feature commit.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test example`.
- [ ] Run `dart analyze` and record errors, warnings, and infos separately.
- [ ] Run `dart test --coverage=coverage` and the repository coverage gate.
- [ ] Run all PTY smoke examples and `dart pub publish --dry-run`.
- [ ] Run `npm ci`, `npm audit --omit=dev`, `npm run typecheck`, and `npm run build` under `website/`.
- [ ] Confirm `git log origin/main..HEAD` contains the planning decision plus exactly one P1 through P9 implementation commit and that only pre-existing ignored/untracked workspace directories remain.
- [ ] Push `codex/release-r1-r8` and confirm draft PR #14 reflects the new commits.
