# Bubble Tea P1–P9 Port Design

## Context

`dart_tui` 1.4.0 already exposes much of Bubble Tea 2's public vocabulary, but
several terminal-facing fields are inert and several Bubbles/Lip Gloss 2
capabilities are absent. This release ports the nine candidates selected in the
release audit. Each port must be useful on its own, covered by regression tests,
and committed independently in P1 through P9 order.

The implementation targets the released upstream behavior in Bubble Tea 2.0.8,
Bubbles 2.1.1, and Lip Gloss 2.0.5. It uses the packages already present in this
repository. It does not add compatibility aliases, feature flags, or migration
layers.

## Chosen approach

Extend the existing immutable Dart models and the two current renderers in
place. Terminal protocols live behind small internal helpers; component state
continues to be represented by new model values returned from methods and
`update`. This matches the current repository architecture while retaining the
observable semantics of the upstream Go APIs.

Rejected alternatives:

- Replacing the renderers with a literal port of Bubble Tea's cursed renderer
  would expand the risk and obscure the nine selected capabilities.
- Maintaining old and new component APIs in parallel would create permanent
  compatibility surfaces and violate the repository contract.
- Adding terminal or Unicode packages is unnecessary because the current ANSI,
  `characters`, RGB, and gradient primitives are sufficient for this scope.

## P1: Complete declarative `View`

Both renderers will own the last applied terminal view state. A render compares
the next `View` with that state and emits transitions for:

- terminal foreground (`OSC 10`) and background (`OSC 11`) color, with `OSC
  110`/`111` reset when a color becomes null;
- native progress (`OSC 9;4`) with clamped values and an explicit reset;
- keyboard enhancement flags, which P1 serializes declaratively and P2 fully
  negotiates and decodes;
- the existing alternate screen, focus, bracketed paste, mouse, title, and
  cursor fields.

`View.onMouse` is evaluated against the last rendered view. The resulting
command is scheduled through the program queue without bypassing model update.
Control bytes are never accepted inside color or progress parameters.

## P2: Kitty progressive keyboard protocol

`KeyboardEnhancements` gains all four released upstream requests: event types,
alternate keys, all keys as escape codes, and associated text. Basic key
disambiguation is always requested when a renderer is active. The renderer
queries enabled flags and resets its level during release/shutdown.

The input decoder will parse Kitty CSI-u responses and key events, including
semicolon subparameters. It maps modifiers, press/repeat/release event types,
shifted and base Unicode code points, and associated text into `TeaKey`.
`KeyboardEnhancementsMsg` exposes a predicate for every flag. Malformed or
unsupported sequences become an unknown key only after a complete CSI sequence
has arrived; partial input remains buffered.

The existing enum-typed shifted/base fields are replaced by Unicode code-point
fields because Kitty reports characters, not `KeyCode` enum values.

## P3: Unicode mode 2027 and grapheme width

At startup, `Program` requests DECRPM status for mode 2027. A supported reset,
set, or permanently-set response enables terminal Unicode core mode. The mode
is disabled on terminal release and restored when the program regains the
terminal.

Cell width calculation moves to one internal grapheme-width function shared by
renderers and components. It treats combining-only clusters as zero width,
emoji presentation and ZWJ clusters as two cells, and East Asian wide/fullwidth
clusters as two cells. Unsupported mode reports leave terminal state unchanged.

## P4: Viewport v2 bundle

`ViewportModel` gains immutable configuration and navigation for:

- a `ViewportGutterBuilder` receiving logical line index, total lines, and
  whether the row is a soft-wrap continuation;
- a per-line `Style Function(int index)` callback;
- grapheme-based `ViewportHighlight` ranges with normal and selected styles;
- `withSearch`, `clearHighlights`, `highlightNext`, and `highlightPrevious`;
- fill-height padding to exactly `height` rows;
- horizontal wheel left/right using the existing mouse button messages.

Search is literal and optionally case-sensitive. Navigation wraps and makes the
selected range visible vertically and horizontally. Empty content, empty
queries, and stale ranges are safe no-ops.

## P5: Dynamic-height textarea

`TextAreaModel` separates visible height from content capacity:

- `dynamicHeight` enables content-driven visible height;
- `minHeight` and `maxHeight` clamp visible rows;
- `maxContentHeight` limits visual rows after soft wrapping;
- PageUp and PageDown move the cursor by the visible page and update scrolling;
- rendering and cursor placement use wrapped visual rows rather than only
  logical newline rows.

Insertion that would exceed `charLimit` or `maxContentHeight` is rejected
without partially changing the model. Deletion can shrink the visible height
and clamps stale scroll offsets.

## P6: Rich progress colors

`ProgressModel` accepts a list of two or more gradient colors, a
`scaleGradient` switch, or a `ProgressColorBuilder(total, current)` callback.
The callback has precedence, then the multi-stop blend, then the existing
filled style. A scaled gradient maps the complete palette over the filled
portion; an unscaled gradient maps it over total bar width. Empty and
single-color inputs reduce to the existing solid behavior.

## P7: Hyperlinks and richer underlines

`Style` gains `UnderlineStyle` (none, single, double, curly, dotted, dashed), an
underline RGB color, and an OSC 8 hyperlink URL/parameter pair. Rendering emits
standard SGR 4 subparameters, SGR 58/59 underline color state, and balanced OSC
8 open/close sequences.

Hyperlink URL and parameters are sanitized by removing C0, DEL, C1, ESC, BEL,
and string-terminator bytes. ANSI-aware wrapping and truncation close active
styles/links before a boundary and reopen them on the next line so terminal
state never leaks.

## P8: Light/dark component defaults

Help, list, text input, textarea, and form style types gain
`forDarkBackground(bool)` and `forBackground(int rgb)` factories. The latter
uses the existing background luminance detector. Defaults remain coherent dark
defaults, while a `BackgroundColorMsg` can be fed directly into a factory by an
application model. No process-global theme state is introduced.

## P9: Input introspection

`TextInputModel` exposes matched suggestions, current suggestion index/current
suggestion, cursor column, and immutable movement to input start/end.
`TextAreaModel` exposes cursor line/column, visible scroll offset, visible
height, and immutable movement to line and document boundaries. All reported
positions are grapheme indexes; terminal-cell conversion remains a rendering
concern.

## Verification and commits

Every port follows red/green/refactor discipline. Its focused tests and static
analysis must pass before a Lore-format commit is created. The final branch gate
runs formatting, repo-wide analysis, the complete Dart suite and coverage,
PTY smoke tests, publish dry-run, website clean install/audit/typecheck/build,
then pushes the branch and updates the existing draft pull request.
