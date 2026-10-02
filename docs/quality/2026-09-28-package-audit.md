# Package quality audit — 2026-09-28

Base: `origin/main` at `4bf5a7d` (version 2.1.0). Scope: the Dart library,
its tests, package configuration, and development tools. The website and
platform-specific Windows console behavior were not exercised. Before edits,
`dart analyze` passed, 739 Dart tests passed, and 12 Python/PTY tests passed.

The table cites locations on the base commit, before this PR moved lines.
"Fixed" means the accompanying patch addresses the finding; the verification
section records the final independent checks.

| Finding on `origin/main` | Consequence and remedy | Disposition |
| --- | --- | --- |
| `lib/src/key_buffer_parser.dart:145` tries four decode lengths, largest first | Adjacent ASCII bytes can become one key event. Decode exactly one ASCII or UTF-8 scalar, wait for a partial scalar, and consume malformed bytes so input makes progress. Benchmark the same stream before and after. | Fixed; parser and streaming tests added. |
| `lib/src/cmd.dart:30` divides by the interval without checking zero | `every(Duration.zero)` fails asynchronously with division by zero. Validate positive intervals at construction; reject negative delays for the other timer helpers. | Fixed; boundary tests added. |
| `lib/src/cmd.dart:162` and `lib/src/program.dart:646` each format `%s` | The same formatting contract can drift. Use one internal formatter for both public entry points. | Fixed. |
| `lib/src/bubbles/list.dart:286-297` clamps empty filtered results against `-1` | Page navigation can throw and downward navigation can leave cursor `-1`. Guard navigation while keeping filter controls available. | Fixed; empty-source and no-match tests added. |
| `lib/src/bubbles/list.dart:330` and `lib/src/prompts.dart:241` delete UTF-16 units | Backspace can leave half an emoji; single-unit input guards also reject one grapheme represented by several units. Edit by grapheme cluster. | Fixed; emoji input/backspace tests added. |
| `lib/src/bubbles/list.dart:257` assumes every described item occupies two rows | Mixed descriptions make mouse clicks select the wrong item. Map clicks over the rows actually rendered. | Fixed; mixed-row click test added. |
| `lib/src/bubbles/file_picker.dart:71,163` cannot clear `selected` and trusts the supplied cursor | A caller cannot reset selection, and Enter can index beyond entries. Add an explicit clear operation, bound the cursor, and normalize invalid heights. | Fixed; selection and bounds tests added. |
| `lib/src/bubbles/file_picker.dart:91-117` turns I/O errors into empty lists | A missing or unreadable directory looks legitimately empty. Preserve a load error and render it distinctly; keep stale-response rejection. | Fixed; missing-directory test added. |
| `lib/src/bubbles/canvas.dart:86` sorts equal z-index layers without a tie-breaker | Documented last-paint-wins behavior relies on an unstable sort. Compare paint order after z-index. | Fixed; many-layer overlap test added. |
| `lib/src/forms/field.dart:180,711` identifies dynamic selection only by index | An initial dynamic selection is ignored, and option reordering can move a multi-selection to another value. Track selected values and discard values removed from the available options. | Fixed; dynamic option tests added. |
| `lib/src/forms/field.dart:191` and `lib/src/forms/form.dart:27-34` rely on asserts for input contracts | Production builds can accept invalid option sources, duplicate keys, or empty groups. Validate these inputs at runtime. | Fixed; invalid-input tests added. |
| `lib/src/forms/form.dart:177-260` can focus notes or hidden fields/groups | An empty focus target can make input edit the wrong field or make navigation incoherent. Normalize focus and skip non-focusable groups; keep an all-hidden form cancellable/submittable. | Fixed; navigation tests added. |
| `lib/src/forms/field.dart:114` splits initial text twice | A large initial field incurs duplicate allocation. Split once for row and column. | Fixed. |
| `lib/src/prompts.dart:51`, `lib/src/gum.dart:89` store completion flags with no readers | State and constructor plumbing suggest behavior that does not exist. Remove the unused flags/getters. | Removed. |
| `lib/src/view.dart:34`, `lib/src/forms/form.dart:47`, `lib/src/key_util.dart:1` expose a delegating setter, a test-only getter, and an empty internal barrel | Redundant production surface and an empty test add maintenance cost. Use observable form tests, public `content`, and delete the empty internal path/export/test. | Removed; unused `meta` dependency removed too. |
| `test/forms/form_styles_test.dart:5` checks mostly unstyled defaults render `x` unchanged | It proves little about custom styles. Assert configured styles affect actual form output. | Replaced. |
| `test/file_picker_performance_test.dart:7` contains concurrency assertions, not timing | The name misdirects maintainers. Keep the useful stale-load tests under an accurate filename. | Renamed to `file_picker_load_test.dart`. |
| `tool/compile_examples.sh:39` ignores each failed compile | The all-examples command reports success despite broken examples. Propagate failures and exercise the shell contract with a fake compiler. | Fixed; Python tests added. |

API note: removing the public `View.setContent` method is source-breaking for
callers that use it. Assign the next release version with that change in mind.
Direct assignment to `View.content` remains available. Multi-select option
values must now be unique; the form rejects duplicate values with
`ArgumentError`. The deleted `key_util.dart` path was inside `src/` and had no
exports.

## Deliberate non-changes and future work

- `lib/src/grapheme_width.dart` uses hand-maintained Unicode width ranges.
  Replacing them needs a chosen Unicode version, terminal policy for ambiguous
  width and variation selectors, and cross-terminal tests. A speculative table
  swap is more dangerous than the current code. This is a feature/design task.
- `lib/src/bubbles/list.dart` paginates by item count. Descriptions can occupy
  extra physical rows; `height` currently means item rows, not terminal rows.
  A physical-row viewport would change pagination, scrolling, and click
  semantics together. Specify that behavior before changing the public model.
- `lib/src/bubbles/canvas.dart` sorts layers each render, but no before/after
  benchmark established that caching helps representative workloads. Keep the
  simple implementation until such a workload exists.
- `lib/src/bubbles/progress.dart:109-145` manually copies many `Style` fields
  to change one color. A narrow immutable `Style` color-copy API could remove
  this maintenance burden, but a new public API and gradient throughput should
  be designed and measured together.
- `lib/src/forms/values.dart:9` uses `has` for key presence, including keys
  whose value is null. That is consistent with a map; changing it to mean
  non-null value would silently change callers. Clarifying documentation is
  safer than treating the present behavior as a bug.
- `tool/compile_examples.sh` and `tool/build.sh --aot` overlap, but have
  different command interfaces and existing callers. The failure-reporting bug
  is fixed; removing either interface requires a migration decision.

Useful next features: a physical-row list viewport for mixed-height items;
configurable file-picker error/retry presentation; and a declared Unicode
width policy with terminal-backed conformance cases. Each needs an explicit
behavior contract before implementation.

## Verification

Final checks on this branch:

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool/core_parser_bench.dart` | 120 files checked; none changed |
| `dart analyze` | No issues |
| `dart test` | 769 passed |
| `bash tool/coverage.sh 90` | 94.5% library line coverage |
| `python3 -m unittest -v tool/bench_command_test.py tool/pty_program_runtime_test.py tool/compile_examples_test.py` | 14 passed |
| `python3 tool/pty_examples_smoke.py` | Four interactive flows passed |
| `bash tool/build.sh --kernel example/simple.dart` | Compiled |

The three adjacent scenario documents give smaller reproductions for the
changed subsystems. Run the parser benchmark on the same runtime when you
compare performance. The emitted event counts differ because the baseline
incorrectly merged input characters. One JIT run here took 970,643 µs for
1,100,000 corrected events while other same-host runs varied substantially;
do not treat a single timing as a stable speed claim.
