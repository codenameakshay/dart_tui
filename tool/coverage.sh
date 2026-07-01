#!/usr/bin/env bash
# Measure lib/ line coverage and fail below a threshold.
#
# Usage: tool/coverage.sh [THRESHOLD]     (default 90)
#   DART=fvm\ dart tool/coverage.sh        (use a different dart launcher)
#
# Honours `// coverage:ignore-{line,start,end,file}` markers (--check-ignore),
# so genuinely-untestable code (Win32 FFI, raw-mode TTY, OS signals) is excluded
# from the denominator rather than force-tested.
set -euo pipefail

THRESHOLD="${1:-90}"
DART="${DART:-dart}"
OUT=".coverage_out"

rm -rf "$OUT"
$DART pub global activate coverage >/dev/null 2>&1 || true
$DART test --coverage="$OUT"
$DART pub global run coverage:format_coverage \
  --lcov --check-ignore --in="$OUT" --out="$OUT/lcov.info" --report-on=lib \
  >/dev/null

pct=$(python3 - "$OUT/lcov.info" <<'PY'
import sys
lf = lh = 0
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith('LF:'):
        lf += int(line[3:])
    elif line.startswith('LH:'):
        lh += int(line[3:])
print(f"{(100 * lh / lf) if lf else 100:.1f}")
PY
)

echo "lib/ line coverage: ${pct}%  (floor: ${THRESHOLD}%)"
if awk "BEGIN { exit !(${pct} >= ${THRESHOLD}) }"; then
  echo "coverage OK"
else
  echo "coverage BELOW floor (${pct}% < ${THRESHOLD}%)" >&2
  exit 1
fi
