#!/usr/bin/env bash
# Build dart_tui examples for faster startup.
#
# KERNEL snapshot (recommended for development / CI):
#   bash tool/build.sh --kernel [example/foo.dart]
#   fvm dart run tool/bin/foo.dill
#   → Skips parse+compile on every run. ~500ms startup on WSL, ~150ms on native Linux.
#
# AOT native executable (for distribution / production):
#   bash tool/build.sh --aot [example/foo.dart]
#   tool/bin/foo
#   → No Dart VM needed at runtime. ~100ms startup.
#
# With no file argument, all example/*.dart files are processed.
set -e
mkdir -p tool/bin

mode=""
files=()

for arg in "$@"; do
  case "$arg" in
    --kernel) mode="kernel" ;;
    --aot)    mode="aot"    ;;
    *)        files+=("$arg") ;;
  esac
done

if [ -z "$mode" ]; then
  echo "Usage: bash tool/build.sh --kernel|--aot [example/foo.dart ...]"
  echo ""
  echo "  --kernel   Pre-compile to .dill kernel snapshot (fast, still uses Dart VM)"
  echo "  --aot      Compile to native executable (fastest, no Dart VM needed)"
  exit 1
fi

if [ ${#files[@]} -eq 0 ]; then
  files=(example/*.dart)
fi

for src in "${files[@]}"; do
  name=$(basename "$src" .dart)
  if [ "$mode" = "kernel" ]; then
    out="tool/bin/$name.dill"
    echo "  kernel  $src → $out"
    fvm dart compile kernel "$src" -o "$out"
  else
    out="tool/bin/$name"
    echo "  aot     $src → $out"
    fvm dart compile exe "$src" -o "$out"
  fi
done

echo ""
if [ "$mode" = "kernel" ]; then
  echo "Done. Run with:  fvm dart run tool/bin/<name>.dill"
  echo "Benchmark:       fvm dart run tool/startup_bench.dart --dill tool/bin/<name>.dill"
else
  echo "Done. Run with:  tool/bin/<name>"
  echo "Benchmark:       fvm dart run tool/startup_bench.dart --aot example/<name>.dart"
fi
