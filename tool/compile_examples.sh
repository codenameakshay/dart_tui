#!/usr/bin/env bash
# Compile all dart_tui examples to native AOT executables.
#
# AOT binaries start in <100ms compared to 3-5s for JIT (`dart run`).
# Use them when distributing CLI tools built with dart_tui.
#
# Usage:
#   bash tool/compile_examples.sh               # compile all examples
#   bash tool/compile_examples.sh simple        # compile single example
#
# Output: tool/bin/<name>  (e.g. tool/bin/simple, tool/bin/spinner)
# Run:    tool/bin/simple

set -euo pipefail

OUTDIR="tool/bin"
mkdir -p "$OUTDIR"

compile_one() {
  local src="example/${1}.dart"
  local out="${OUTDIR}/${1}"
  if [[ ! -f "$src" ]]; then
    echo "Error: $src not found" >&2
    return 1
  fi
  echo -n "  compiling $1 ... "
  fvm dart compile exe "$src" -o "$out" 2>/dev/null
  echo "ok  → $out"
}

if [[ $# -gt 0 ]]; then
  compile_one "$1"
else
  echo "Compiling all examples to $OUTDIR/"
  echo ""
  for f in example/*.dart; do
    name=$(basename "$f" .dart)
    compile_one "$name" || true
  done
  echo ""
  echo "Done. Run any example with: $OUTDIR/<name>"
  echo "Benchmark AOT vs JIT:  fvm dart run tool/startup_bench.dart --aot example/simple.dart"
fi
