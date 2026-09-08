# Performance audit and reproducible results

This document records the reproducible `dart_tui` baseline, measured
workload results, and implementation audit. It is intentionally evidence
based: a covered line is not the same as a user-visible performance guarantee,
and this document does not claim that every component has been stress tested.

## Baseline

The baseline was an archive checkout of `e00de92` (`origin/main`) in a
temporary directory, so concurrent worktree edits could not affect the result.
The host was macOS arm64 with Dart 3.13.1 and Python 3.13.7.

| Check | Result |
| --- | --- |
| `dart test` | 698 passed |
| `dart analyze` | No issues |
| `python3 -m unittest -v tool/bench_command_test.py` | 6 passed |
| `python3 -m unittest -v tool/pty_program_runtime_test.py` | 4 passed |
| `python3 tool/pty_examples_smoke.py` | 4 passed |
| Example AOT compilation | 61/61 compiled |
| Library line coverage | 4,154/4,422, 93.9% |

The baseline was run with:

```sh
dart pub get
dart test
dart analyze
python3 -m unittest -v tool/bench_command_test.py
python3 -m unittest -v tool/pty_program_runtime_test.py
python3 tool/pty_examples_smoke.py
bash tool/compile_examples.sh
bash tool/coverage.sh 0
```

`tool/compile_examples.sh` prints success for each example but masks an
individual compile failure with `|| true`; the 61/61 result above was checked
independently from its per-example output.

## Startup measurements

The more reliable comparison used `tool/bench_command.py` with the same
short-lived PTY probe in each mode (5 runs, one warmup excluded). It measures
time to the first visible character and verifies that the child exits.

| Mode | Median first visible | p95 first visible | Median total runtime |
| --- | ---: | ---: | ---: |
| JIT source | 553 ms | 895 ms | 808 ms |
| Kernel snapshot | 158 ms | 216 ms | 410 ms |
| AOT executable | 11 ms | 16 ms | 265 ms |

The existing `tool/startup_bench.dart` reported medians of 636 ms for JIT,
143 ms for kernel, and 17 ms for AOT on `example/simple.dart`. That tool waits
for the first stdout byte, which can be terminal control output rather than a
visible frame. Its documentation says two runs while the implementation runs
three. Also, `--all --dill` labels the run as a dill benchmark but passes the
source example path to the child. Use the PTY benchmark for before/after
comparisons until those semantics are corrected.

The AOT steady-state result is 11 ms median in this baseline. There is no
measured need for a Rust rendering or startup backend. A Rust rewrite should be
reconsidered only if a representative workload shows Dart AOT missing a
product requirement after the current hot paths are measured.

## Final JIT workload comparison

These are the serial JIT runs from the exact audit workloads. Each row is a
microbenchmark with its own operation count; the ratio is useful for that
workload only and is not a universal application multiplier. Checksums and
assertions were retained to catch work being skipped.

| Workload | Operations | Baseline median | Current median | Ratio | Check |
| --- | ---: | ---: | ---: | ---: | --- |
| getWidth plain | 10,000 calls | 215,764 us | 42,446 us | 5.1x | nonzero result |
| getWidth ANSI | 10,000 calls | 618,849 us | 42,747 us | 14.5x | nonzero result |
| Style ANSI-256 | 10,000 renders | 903,818 us | 186,660 us | 4.8x | nonzero result |
| Tokenize styled ANSI | 3 samples, 50k styled input | 133,761 us | 1,397 us | 95.8x | nonempty tokens |
| Cell alternating frames | 1,000 renders | 25,391 us | 8,547 us | 3.0x | nonempty sink |
| Cell identical frames | 1,000 renders | 204 us | 201 us | 1.0x | nonempty sink |
| TextArea update/view | 300 update+view cycles | 908,891 us | 24,549 us | 37.0x | combined checksum 18,483,258 |
| Canvas clipped styled line | 1 render of 50k-char line | 362,019 us | 163 us | 2,221x | output length assertion |
| TextInput navigation/view | 1,200 update+view cycles | 895,482 us | 192,385 us | 4.7x | combined checksum 18,483,258 |
| Decoder plain buffer | 100,000 bytes | 2,362.855 ms | 2.494 ms | 947x | checksum 125,000 |
| Decoder bracketed paste | 100,012 bytes | 455.605 ms | 2.246 ms | 203x | checksum 50,012 |
| Decoder fragmented OSC | 50,007 bytes, 1-byte chunks | 2,474.301 ms | 3.633 ms | 681x | checksum 2 |
| Decoder fragmented DCS | 50,007 bytes, 1-byte chunks | 2,077.069 ms | 3.171 ms | 655x | checksum 25,008 |
| Decoder fragmented CSI | 50,004 bytes, 1-byte chunks | 1,975.452 ms | 3.051 ms | 648x | checksum 2 |
| Viewport soft-wrap scroll/view | 20 scroll+view cycles, 4,000 lines | 1,967,047 us | 25,068 us | 78.4x | checksum 31,320 |
| Viewport highlights scroll/view | 20 cycles, 1,000 highlights | 14,138,679 us | 9,395 us | 1,505x | checksum 42,700 |

The text-component checksum is the aggregate over three cases and six samples;
the decoder checksums are per case. The measurements show large gains in
allocation-heavy synthetic inputs and preserve the reported checksums. They do
not establish per-keystroke latency,
frame-rate behavior under real terminal output, or equal gains for every
component. AOT corroboration should use the same four workload commands and
be read separately from these JIT ratios.

## Native AOT corroboration

The native runs use the same operation counts as the JIT table. The renderer
tool reports medians of five samples (three for the 50k-token case); the text
and decoder tools discard one warmup and report medians of the remaining five.
No AOT viewport run was collected.

| Workload | Baseline AOT | Current AOT | Ratio | Check |
| --- | ---: | ---: | ---: | --- |
| getWidth plain, 10,000 calls | 162,297 us | 55,852 us | 2.9x | nonzero result |
| getWidth ANSI, 10,000 calls | 574,524 us | 58,953 us | 9.7x | nonzero result |
| Style ANSI-256, 10,000 renders | 784,359 us | 240,459 us | 3.3x | nonzero result |
| Tokenize styled ANSI, 50k input | 125,146 us | 847 us | 147.7x | nonempty tokens |
| Cell alternating frames, 1,000 renders | 28,533 us | 8,734 us | 3.3x | nonempty sink |
| Cell identical frames, 1,000 renders | 60 us | 24 us | 2.5x | nonempty sink |
| TextArea update/view, 300 cycles | 701,612 us | 13,581 us | 51.7x | combined checksum 18,483,258 |
| Canvas clipped styled line, 50k chars | 304,386 us | 57 us | 5,340x | output length assertion |
| TextInput navigation/view, 1,200 cycles | 642,667 us | 167,116 us | 3.8x | combined checksum 18,483,258 |
| Decoder plain buffer, 100,000 bytes | 1,958.058 ms | 2.824 ms | 693x | checksum 125,000 |
| Decoder bracketed paste, 100,012 bytes | 95.964 ms | 1.740 ms | 55.1x | checksum 50,012 |
| Decoder fragmented OSC, 50,007 bytes | 849.064 ms | 3.193 ms | 266x | checksum 2 |
| Decoder fragmented DCS, 50,007 bytes | 599.401 ms | 3.790 ms | 158x | checksum 25,008 |
| Decoder fragmented CSI, 50,004 bytes | 678.404 ms | 3.187 ms | 213x | checksum 2 |

## Reproducing workload measurements

Use `SOURCE` for a checkout containing the four benchmark tools. The baseline
ref predates those tools, so the commands copy the same tool sources into each
archive before running it. The archive keeps generated binaries and dependency
metadata outside the shared worktree.

```sh
SOURCE=${SOURCE:-${PWD}}
for REF in e00de92 HEAD; do
CHECKOUT=$(mktemp -d)
git archive "$REF" | tar -x -C "$CHECKOUT"
for bench in bubbles_bench input_decoder_bench render_width_perf_bench text_components_bench; do
  cp "$SOURCE/tool/$bench.dart" "$CHECKOUT/tool/$bench.dart"
done
(
  cd "$CHECKOUT"
  dart pub get
  for bench in bubbles_bench input_decoder_bench render_width_perf_bench text_components_bench; do
    dart run "tool/$bench.dart"
  done
)
done
```

To run the same four workloads as native AOT executables:

```sh
SOURCE=${SOURCE:-${PWD}}
for REF in e00de92 HEAD; do
  CHECKOUT=$(mktemp -d)
  git archive "$REF" | tar -x -C "$CHECKOUT"
  for bench in bubbles_bench input_decoder_bench render_width_perf_bench text_components_bench; do
    cp "$SOURCE/tool/$bench.dart" "$CHECKOUT/tool/$bench.dart"
  done
  (
    cd "$CHECKOUT"
    dart pub get
    mkdir -p .bench-bin
    for bench in bubbles_bench input_decoder_bench render_width_perf_bench text_components_bench; do
      dart compile exe "tool/$bench.dart" -o ".bench-bin/$bench"
      ".bench-bin/$bench"
    done
  )
done
```

Record the host, Dart version, exact commit, warmup policy, and median output
from every run. Startup measurements use the PTY probe separately because a
long-lived interactive example cannot be compared fairly by waiting for
natural process exit.

## Audit findings

All 49 library files were included in this grouped audit. The coverage value
is the baseline LCOV result; the findings describe the current performance
work and its scope.

| Area and files | Baseline coverage | Findings and action | Remaining limits |
| --- | ---: | --- | --- |
| Renderer and terminal state: ansi_state.dart, grapheme_width.dart, renderer.dart, terminal_mode_state.dart, terminal_view_state.dart, view.dart | 533 / 539 (98.9%) | ANSI tokenization walks plain spans without copying suffixes; stripping consumes controls directly; grapheme width avoids rune-list allocation; the ANSI palette is reused; renderer style reads are hoisted. | ANSI control parsing is still terminal-sensitive and needs PTY validation. |
| Text, layout, and components: all 22 files under bubbles/ | 2,158 / 2,290 (94.2%) | TextArea caches immutable rows; TextInput caches grapheme and suggestion work; Canvas clips its styled-run scan; Viewport caches only the no-gutter path, indexes highlights per line, and caches no-wrap longest width; Tree uses path offsets instead of sublists; MultiSelect counts selected rows without allocating a selected list; FilePicker filters before sorting and uses a shared per-request generation to reject stale same-location reloads. | Viewport gutter callbacks preserve their existing behavior and therefore keep a slower path. ListModel filter-cache ownership is kept local because its collection is mutable; freezing or sharing that cache would change its mutable semantics. Small unchanged components have no measured hot-path issue. |
| Input and interaction: input_decoder.dart, key_buffer_parser.dart, kitty_keyboard.dart | 404 / 431 (93.7%) | The parser uses an offset cursor instead of repeatedly removing the front of a buffer; OSC/DCS/CSI scanning resumes across fragmented input. | Malformed and fragmented streams still require decoder tests and PTY boundary checks. |
| Program, commands, prompts, and logging: cmd.dart, gum.dart, log.dart, model.dart, msg.dart, program.dart, prompts.dart, terminal_control.dart | 612 / 690 (88.7%) | No runtime Program rewrite is claimed. Its idle activity wake and batch handling already exist; command and message helpers have no measured hot-path issue. | Program coverage is the lowest group; runtime behavior and terminal lifecycle remain separate gates. |
| Forms: forms/field.dart, forms/form.dart, forms/form_styles.dart, forms/values.dart | 447 / 472 (94.7%) | Form operations read raw values once, preserving mutable group behavior while avoiding repeated lookup work. | Form interaction remains model-dependent and is not represented by startup timings. |
| Barrels and platform-only files: dart_tui.dart, bubbles.dart, core.dart, forms.dart, key_util.dart, windows_terminal.dart | no executable lines | Public barrel exports were inspected; no optimization is appropriate in these files. | LCOV cannot measure export coverage or platform-only branches here. |

The lowest executable-line coverage is in program.dart (80.6%),
key_buffer_parser.dart (83.3%), and view.dart (83.3%). These values guide
future tests but do not establish a performance regression.

## Audit scope and interpretation

The package surface was checked through the public barrels in
`lib/dart_tui.dart`, `lib/src/core.dart`, `lib/src/bubbles.dart`, and
`lib/src/forms.dart`. The archive contains 61 top-level examples and 49
library files. The PTY smoke suite exercises four representative interactive
flows; the remaining examples were compiled but not each behaviorally driven.

The current worktree contains performance changes in renderer, width/ANSI,
input decoding, viewport, canvas, file picker, multi-select, and text
components, plus focused tests and benchmark tools. The measured comparisons
use the same workload definitions and checksums across baseline and current
runs.

Residual limits are terminal- and host-dependent startup variance, coverage
that does not replace workload benchmarks, and the fact that compilation does
not prove every interactive example exits correctly under all terminal modes.

## Final validation

The final local gates completed with:

| Gate | Result |
| --- | --- |
| `dart analyze` | clean |
| `dart format` | 217 files checked, 0 changes |
| Coverage script | 722 tests passed, 93.6% library coverage |
| Benchmark unit tests | 6 passed |
| PTY lifecycle tests | 4 passed |
| Example smoke checks | 4 passed |
| Example AOT compilation | 61/61 compiled with each return code enforced |

The four example smoke checks verify interactive output and terminal markers;
the harness terminates each child after its markers appear. They are not proof
that all four examples naturally exit. The separate PTY lifecycle suite covers
kill, cancellation, resize, and suspend/resume restoration.

## Known PTY lifecycle limitation

A real PTY probe of `example/file_picker.dart` loaded with
`analysis_options.yaml` and sent `ESC` captured restored cursor,
alternate-screen, and bracketed-paste modes in both the current tree and
`e00de92`, but neither process naturally exited within six seconds; both had
to be killed after capture. The known stdin lifecycle issue remains open in
[issue #15](https://github.com/codenameakshay/dart_tui/issues/15) with separate
work in [PR #17](https://github.com/codenameakshay/dart_tui/pull/17). The
performance scope does not resolve that lifecycle contract.
