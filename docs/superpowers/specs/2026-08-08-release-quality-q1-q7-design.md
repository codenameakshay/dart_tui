# Release Quality Q1-Q7 Design

## Goal

Complete the seven quality candidates selected from the release audit while
keeping every change independently testable, reviewable, and reversible.

## Constraints

- Work on the existing `codex/release-r1-r8` release branch.
- Implement Q1 through Q7 in order and commit each identifier separately.
- Add no dependencies and preserve no obsolete compatibility surfaces.
- Keep the two renderer strategies separate while sharing terminal-mode state.
- Use only the standard Dart, Python, Make, and GitHub Actions capabilities
  already present in the repository.

## Design

### Q1: PTY runtime characterization

Add a small Dart runtime probe and a Python standard-library PTY harness. The
harness will exercise idle `Program.kill()`, external cancellation, SIGWINCH
resize delivery, SIGTSTP/SIGCONT suspend-resume behavior, and terminal cleanup.
It will run only on Unix, beside the existing example PTY smoke test in CI.
Each scenario has a bounded timeout and validates observable terminal output
instead of reaching into private runtime state.

### Q2: Shared terminal-mode state

Move alternate-screen, cursor-visibility, focus-reporting, bracketed-paste,
and mouse-mode transitions into one `TerminalModeState` helper. Both renderers
will retain their own frame caches and diff algorithms, but delegate mode
application, imperative transitions, and reset emission to the helper. Screen
changes return an explicit signal so each renderer invalidates only its own
cache.

### Q3: One analyzer boundary

Make the local `make analyze` target run the same repository-wide command as
CI. Exclude the website's verbatim, slug-named Dart mirrors in
`analysis_options.yaml`; the canonical examples remain analyzed, while the
website copies remain validated by TypeScript and the website build. This
removes the ten filename notices without renaming public documentation slugs.

### Q4: Plain-Dart Make targets

Set `DART ?= dart`, preserving an explicit caller override such as
`make DART='fvm dart'`. Update the help and contributor documentation so a
normal Dart SDK is the default and FVM is optional.

### Q5: Current tooling constraints

Use `dart pub outdated` and the current SDK resolver to select the newest
compatible releases of the existing `meta`, `lints`, and `test` packages.
Change only existing constraints, regenerate resolution state as needed, and
run analysis plus the full test suite. No package is added.

### Q6: Smaller published archive

Point README previews at the already deployed documentation site's `/gifs/`
assets, then exclude `example/tapes/output/` from the pub archive. Keep the
recording sources and repository previews available to contributors. A pub
dry run must contain no GIF payload while retaining zero warnings.

### Q7: Remove compatibility APIs

Remove `TeaModel`, `LegacyKeyMsg`, `TuiStyle`, and `ProgramOptions` outright.
`Model`, `KeyPressMsg`, immutable `Style`, and `List<ProgramOption>` become the
only supported paths. Add `withLogFile` so the option-function API retains the
existing logging capability. Update library code, tests, examples, generated
website source mirrors, and documentation in the same breaking commit. No
aliases, deprecated wrappers, or fallback constructors remain.

## Verification

Every Q commit gets its focused red/green or characterization command before
the next task starts. The final gate runs formatting, repository-wide analysis,
the full Dart suite with the 90% coverage floor, both PTY harnesses, example
compilation, pub dry-run validation, website audit/typecheck/build, and a scan
confirming that all four Q7 symbols are gone.

## Scope Review

The design covers every selected Q identifier, introduces no placeholder work,
and makes the deliberate Q7 breaking change explicit. Runtime behavior remains
modular: Q1 observes it externally, Q2 owns terminal modes, and Q7 removes only
obsolete public entry points.
